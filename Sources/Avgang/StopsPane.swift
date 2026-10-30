import AvgangCore
import Observation
import SwiftUI

@MainActor
@Observable
final class StopCatalog {
  static let searchDelay: Duration = .milliseconds(250)

  var query = "" {
    didSet { if query != oldValue { search() } }
  }
  private(set) var results: [StopMatch] = []
  private(set) var searchFailed = false
  private(set) var platforms: [String: [Platform]] = [:]
  private(set) var platformsFailed: Set<String> = []
  @ObservationIgnored private let client: EnturClient
  @ObservationIgnored private var searching: Task<Void, Never>?

  init(client: EnturClient) {
    self.client = client
  }

  func clear() {
    query = ""
    results = []
  }

  func loadPlatforms(for id: String) async {
    guard platforms[id] == nil else { return }
    do {
      platforms[id] = try await client.platforms(stopID: id)
      platformsFailed.remove(id)
    } catch {
      platformsFailed.insert(id)
    }
  }

  private func search() {
    searching?.cancel()
    let text = query
    searching = Task { [weak self, client] in
      try? await Task.sleep(for: Self.searchDelay)
      guard !Task.isCancelled else { return }
      do {
        let found = try await client.search(text)
        guard !Task.isCancelled else { return }
        self?.results = found
        self?.searchFailed = false
      } catch is CancellationError {
        return
      } catch {
        self?.results = []
        self?.searchFailed = true
      }
    }
  }
}

struct StopsPane: View {
  @Bindable var monitor: Monitor
  @State private var catalog: StopCatalog
  @State private var selection: String?

  init(monitor: Monitor) {
    self.monitor = monitor
    _catalog = State(initialValue: StopCatalog(client: monitor.client))
  }

  var body: some View {
    HStack(alignment: .top, spacing: 0) {
      VStack(alignment: .leading, spacing: 8) {
        searchField
        if !matches.isEmpty || catalog.searchFailed { results }
        List(selection: $selection) {
          ForEach(monitor.settings.favorites) { favorite in
            FavoriteRow(favorite: favorite, platforms: catalog.platforms[favorite.id])
              .tag(favorite.id)
          }
          .onMove { monitor.settings.favorites.move(fromOffsets: $0, toOffset: $1) }
        }
        .listStyle(.bordered)
        .alternatingRowBackgrounds(.disabled)
        Text(
          monitor.settings.follow == .firstFavorite
            ? "Drag to reorder. The first stop drives the menu bar label." : "Drag to reorder."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }
      .padding(16)
      .frame(width: SettingsMetrics.listWidth)
      Divider()
      detail.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .frame(width: SettingsMetrics.width, height: SettingsMetrics.stopsHeight)
    .task {
      if selection == nil { selection = monitor.settings.favorites.first?.id }
      for favorite in monitor.settings.favorites {
        await catalog.loadPlatforms(for: favorite.id)
      }
    }
  }

  private var matches: [StopMatch] {
    let saved = Set(monitor.settings.favorites.map(\.id))
    return catalog.results.filter { !saved.contains($0.id) }
  }

  private var searchField: some View {
    HStack(spacing: 6) {
      Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
      TextField("Add a stop", text: $catalog.query)
        .textFieldStyle(.plain)
    }
    .padding(.horizontal, 8)
    .frame(height: 28)
    .background(.background, in: .rect(cornerRadius: 7))
    .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(.separator))
  }

  private var results: some View {
    VStack(alignment: .leading, spacing: 0) {
      if catalog.searchFailed {
        Text("Could not search. Check your connection.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .padding(8)
      }
      ForEach(matches) { match in
        Button {
          add(match)
        } label: {
          HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
              Text(match.name).lineLimit(1)
              if let locality = match.locality {
                Text(locality).font(.caption).foregroundStyle(.secondary)
              }
            }
            Spacer(minLength: 4)
            ModeIcons(modes: match.modes)
            Image(systemName: "plus")
          }
          .padding(.horizontal, 8)
          .padding(.vertical, 5)
          .contentShape(.rect)
        }
        .buttonStyle(.plain)
      }
    }
    .background(.background, in: .rect(cornerRadius: 7))
    .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(.separator))
  }

  @ViewBuilder private var detail: some View {
    if let index = monitor.settings.favorites.firstIndex(where: { $0.id == selection }) {
      let current = monitor.settings.favorites[index]
      FavoriteDetail(
        favorite: Binding(
          get: { monitor.settings.favorites.first { $0.id == current.id } ?? current },
          set: { edited in
            guard let at = monitor.settings.favorites.firstIndex(where: { $0.id == current.id })
            else { return }
            monitor.settings.favorites[at] = edited
          }),
        location: monitor.location,
        platforms: catalog.platforms[current.id],
        failed: catalog.platformsFailed.contains(current.id),
        retry: { Task { await catalog.loadPlatforms(for: current.id) } },
        remove: { remove(at: index) }
      )
      .id(current.id)
    } else {
      Text("Search for a stop to add it.")
        .foregroundStyle(.secondary)
    }
  }

  private func add(_ match: StopMatch) {
    monitor.settings.favorites.append(Favorite(match: match, from: monitor.location))
    selection = match.id
    catalog.clear()
    Task { await catalog.loadPlatforms(for: match.id) }
  }

  private func remove(at index: Int) {
    monitor.settings.favorites.remove(at: index)
    let remaining = monitor.settings.favorites
    selection = remaining.indices.contains(index) ? remaining[index].id : remaining.last?.id
  }
}

private struct FavoriteRow: View {
  let favorite: Favorite
  let platforms: [Platform]?

  var body: some View {
    HStack(spacing: 8) {
      VStack(alignment: .leading, spacing: 1) {
        Text(favorite.name).lineLimit(1)
        Text(summary).font(.caption).foregroundStyle(.secondary).lineLimit(1)
      }
      Spacer(minLength: 4)
      ModeIcons(modes: favorite.modes)
    }
    .padding(.vertical, 2)
  }

  private var summary: String {
    let walk = String(localized: "\(favorite.walkMinutes) min walk")
    guard !favorite.excludedQuays.isEmpty else {
      return String(localized: "All platforms, \(walk)")
    }
    let codes = (platforms ?? [])
      .filter { !favorite.excludedQuays.contains($0.id) }
      .compactMap(\.code)
    guard !codes.isEmpty else { return walk }
    return String(localized: "Platform \(codes.joined(separator: ", ")), \(walk)")
  }
}

private struct FavoriteDetail: View {
  @Binding var favorite: Favorite
  let location: Coordinate?
  let platforms: [Platform]?
  let failed: Bool
  let retry: () -> Void
  let remove: () -> Void

  var body: some View {
    Form {
      Section {
        if let platforms {
          ForEach(platforms) { platform in
            Toggle(isOn: included(platform.id, in: \.excludedQuays)) {
              HStack(spacing: 8) {
                if let code = platform.code { PlatformChip(code: code, tint: .secondary) }
                Text(towards(platform)).lineLimit(2)
              }
            }
            .toggleStyle(.checkbox)
          }
        } else if failed {
          HStack {
            Text("Could not load platforms.").foregroundStyle(.secondary)
            Spacer()
            Button("Try again", action: retry)
          }
        } else {
          ProgressView().controlSize(.small).frame(maxWidth: .infinity)
        }
      }
      if !lines.isEmpty {
        Section {
          LabeledContent("Lines") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 40), spacing: 6)], spacing: 6) {
              ForEach(lines) { line in
                let shown = !favorite.excludedLines.contains(line.id)
                Button {
                  included(line.id, in: \.excludedLines).wrappedValue.toggle()
                } label: {
                  LineBadge(line: line, height: 24, fontSize: 13).opacity(shown ? 1 : 0.3)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(shown ? .isSelected : [])
              }
            }
            .frame(maxWidth: 220)
          }
        }
      }
      Section {
        Toggle("Walking time from my location", isOn: $favorite.walkFromLocation)
        if favorite.walkFromLocation, location != nil {
          LabeledContent(
            "Walking time", value: String(localized: "\(favorite.walk(from: location)) min"))
        } else {
          NumberField(
            title: "Walking time", value: $favorite.walkMinutes, range: Favorite.walkRange,
            unit: "min")
        }
        Toggle("Hide departures I can't reach", isOn: $favorite.hideUnreachable)
        NumberField(
          title: "Departures shown", value: $favorite.shown, range: Favorite.shownRange)
      }
      Section {
        Button("Remove \(favorite.name)", role: .destructive, action: remove)
      }
    }
    .formStyle(.grouped)
  }

  private var lines: [Line] {
    var seen = Set<String>()
    return (platforms ?? []).flatMap(\.lines)
      .filter { seen.insert($0.id).inserted }
      .sorted { $0.code.localizedStandardCompare($1.code) == .orderedAscending }
  }

  private func towards(_ platform: Platform) -> String {
    let places = platform.destinations.prefix(4)
    guard !places.isEmpty else { return platform.lines.map(\.code).joined(separator: ", ") }
    return String(localized: "Towards \(places.joined(separator: ", "))")
  }

  private func included(_ id: String, in path: WritableKeyPath<Favorite, Set<String>>) -> Binding<
    Bool
  > {
    Binding(
      get: { !favorite[keyPath: path].contains(id) },
      set: { shown in
        if shown {
          favorite[keyPath: path].remove(id)
        } else {
          favorite[keyPath: path].insert(id)
        }
      })
  }
}

struct ModeIcons: View {
  let modes: [TransportMode]

  var body: some View {
    HStack(spacing: 3) {
      ForEach(modes.filter { $0 != .unknown }, id: \.self) { mode in
        Image(systemName: mode.symbol).accessibilityLabel(Text(mode.title))
      }
    }
    .font(.system(size: 11))
    .foregroundStyle(.secondary)
  }
}
