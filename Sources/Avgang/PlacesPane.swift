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
        client: monitor.client,
        relocate: { relocate(current.id, to: $0) },
        addStop: { monitor.settings.add($0, toPlace: current.id) },
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
    adoptClosestStop(for: place)
  }

  private func relocate(_ id: String, to coordinate: Coordinate) {
    monitor.settings.move(place: id, to: coordinate)
    guard let place = monitor.settings.places.first(where: { $0.id == id }) else { return }
    adoptClosestStop(for: place)
  }

  private func adoptClosestStop(for place: Place) {
    guard place.stops.isEmpty else { return }
    Task {
      guard
        let stops = try? await monitor.client.nearby(around: place.coordinate, within: place.radius)
      else { return }
      monitor.settings.adoptClosest(of: stops, forPlace: place.id)
    }
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
  let relocate: (Coordinate) -> Void
  let addStop: (StopMatch) -> Void
  let remove: () -> Void
  @State private var addresses: StopCatalog
  @State private var stops: StopCatalog

  init(
    place: Binding<Place>, favorites: [Favorite], location: Coordinate?, client: EnturClient,
    relocate: @escaping (Coordinate) -> Void, addStop: @escaping (StopMatch) -> Void,
    remove: @escaping () -> Void
  ) {
    _place = place
    self.favorites = favorites
    self.location = location
    self.relocate = relocate
    self.addStop = addStop
    self.remove = remove
    _addresses = State(initialValue: StopCatalog(client: client, layers: "address,stopPlace"))
    _stops = State(initialValue: StopCatalog(client: client))
  }

  var body: some View {
    Form {
      Section {
        TextField("Name", text: $place.name)
        LabeledContent("Location") {
          HStack(spacing: 8) {
            if let near { Text("Near \(near)").foregroundStyle(.secondary) }
            Button("Use where I am") {
              if let location { relocate(location) }
            }
            .disabled(location == nil)
          }
        }
        SearchField(title: "Search an address", text: $addresses.query)
        if !addressMatches.isEmpty || addresses.searchFailed {
          MatchList(matches: addressMatches, failed: addresses.searchFailed) { match in
            relocate(match.coordinate)
            addresses.clear()
          }
        }
        NumberField(title: "Within", value: $place.radius, range: Place.radiusRange, unit: "m")
      }
      Section {
        SearchField(title: "Add a stop", text: $stops.query)
        if !stopMatches.isEmpty || stops.searchFailed {
          MatchList(matches: stopMatches, failed: stops.searchFailed) { match in
            addStop(match)
            stops.clear()
          }
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
    .onChange(of: place.coordinate, initial: true) { stops.focus = place.coordinate }
  }

  private var addressMatches: [StopMatch] {
    addresses.query.isEmpty ? [] : addresses.results
  }

  private var stopMatches: [StopMatch] {
    guard !stops.query.isEmpty else { return [] }
    return stops.results
      .filter { !place.stops.contains($0.id) }
      .sorted { place.distance(to: $0.coordinate) < place.distance(to: $1.coordinate) }
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
