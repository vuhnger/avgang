import AvgangCore
import SwiftUI

struct PlacesPane: View {
  @Bindable var monitor: Monitor
  @State private var catalog: StopCatalog
  @State private var selection: String?

  init(monitor: Monitor) {
    self.monitor = monitor
    _catalog = State(
      initialValue: StopCatalog(client: monitor.client, layers: "address,stopPlace"))
  }

  var body: some View {
    HStack(alignment: .top, spacing: 0) {
      VStack(alignment: .leading, spacing: 8) {
        SearchField(title: "Add a place", text: $catalog.query)
        if here != nil || !matches.isEmpty || catalog.searchFailed {
          MatchList(matches: matches, failed: catalog.searchFailed, add: add, here: here)
        }
        List(selection: $selection) {
          ForEach(monitor.settings.places) { place in
            PlaceRow(place: place).tag(place.id)
          }
        }
        .listStyle(.bordered)
        .alternatingRowBackgrounds(.disabled)
        Text("Search an address or stop, or add where you are now.")
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
      if selection == nil { selection = monitor.settings.places.first?.id }
    }
  }

  private var matches: [StopMatch] {
    catalog.query.isEmpty ? [] : catalog.results
  }

  private var here: (() -> Void)? {
    guard catalog.query.isEmpty, let location = monitor.location else { return nil }
    return { insert(Place(name: String(localized: "New place"), coordinate: location)) }
  }

  @ViewBuilder private var detail: some View {
    if let index = monitor.settings.places.firstIndex(where: { $0.id == selection }) {
      let current = monitor.settings.places[index]
      PlaceDetail(
        place: Binding(
          get: { monitor.settings.places.first { $0.id == current.id } ?? current },
          set: { edited in
            guard let at = monitor.settings.places.firstIndex(where: { $0.id == current.id })
            else { return }
            monitor.settings.places[at] = edited
          }),
        favorites: monitor.settings.favorites,
        location: monitor.location,
        remove: { remove(at: index) }
      )
      .id(current.id)
    } else {
      Text("Search for an address or stop to add a place.")
        .foregroundStyle(.secondary)
    }
  }

  private func add(_ match: StopMatch) {
    insert(Place(name: match.name, coordinate: match.coordinate))
  }

  private func insert(_ place: Place) {
    monitor.settings.places.append(place)
    selection = place.id
    catalog.clear()
  }

  private func remove(at index: Int) {
    monitor.settings.places.remove(at: index)
    let remaining = monitor.settings.places
    selection = remaining.indices.contains(index) ? remaining[index].id : remaining.last?.id
  }
}

private struct PlaceRow: View {
  let place: Place

  var body: some View {
    VStack(alignment: .leading, spacing: 1) {
      Text(place.name).lineLimit(1)
      Text(summary).font(.caption).foregroundStyle(.secondary).lineLimit(1)
    }
    .padding(.vertical, 2)
  }

  private var summary: String {
    place.stops.count == 1
      ? String(localized: "1 stop, within \(place.radius) m")
      : String(localized: "\(place.stops.count) stops, within \(place.radius) m")
  }
}

private struct PlaceDetail: View {
  @Binding var place: Place
  let favorites: [Favorite]
  let location: Coordinate?
  let remove: () -> Void

  var body: some View {
    Form {
      Section {
        TextField("Name", text: $place.name)
        LabeledContent("Location") {
          HStack(spacing: 8) {
            if let near { Text("Near \(near)").foregroundStyle(.secondary) }
            Button("Use where I am") {
              if let location { place.coordinate = location }
            }
            .disabled(location == nil)
          }
        }
        NumberField(title: "Within", value: $place.radius, range: Place.radiusRange, unit: "m")
      }
      Section {
        if favorites.isEmpty {
          Text("Add stops under Stops first.").foregroundStyle(.secondary)
        }
        ForEach(favorites) { favorite in
          Toggle(favorite.name, isOn: checked(favorite.id))
            .toggleStyle(.checkbox)
        }
      }
      Section {
        Button("Remove \(place.name)", role: .destructive, action: remove)
      }
    }
    .formStyle(.grouped)
  }

  private var near: String? {
    favorites
      .map { (name: $0.name, distance: place.distance(to: $0.coordinate)) }
      .filter { $0.distance <= Double(place.radius) }
      .min { $0.distance < $1.distance }?
      .name
  }

  private func checked(_ id: String) -> Binding<Bool> {
    Binding(
      get: { place.stops.contains(id) },
      set: { on in
        if on {
          place.stops.insert(id)
        } else {
          place.stops.remove(id)
        }
      })
  }
}
