import Foundation

public enum MenuBarStyle: String, Codable, Sendable, CaseIterable {
  case icon
  case next
  case leave
}

public enum Follow: String, Codable, Sendable, CaseIterable {
  case firstFavorite
  case nearest
}

public enum OpenWith: String, Codable, Sendable, CaseIterable {
  case hover
  case click
}

public struct Favorite: Codable, Equatable, Sendable, Identifiable {
  public static let walkRange = 0...30
  public static let shownRange = 1...10

  public let id: String
  public var name: String
  public var coordinate: Coordinate
  public var modes: [TransportMode]
  public var walkMinutes = 5
  public var walkFromLocation = false
  public var hideUnreachable = true
  public var shown = 5
  public var excludedQuays: Set<String> = []
  public var excludedLines: Set<String> = []

  public init(match: StopMatch, from location: Coordinate?) {
    id = match.id
    name = match.name
    coordinate = match.coordinate
    modes = match.modes
    if let location {
      walkMinutes = min(
        Self.walkRange.upperBound, Walking.minutes(meters: location.distance(to: match.coordinate)))
    }
  }

  public func walk(from location: Coordinate?) -> Int {
    guard walkFromLocation, let location else { return walkMinutes }
    return Walking.minutes(meters: location.distance(to: coordinate))
  }

  public func keeps(_ departure: Departure) -> Bool {
    !excludedQuays.contains(departure.quayID) && !excludedLines.contains(departure.line.id)
  }

  private enum CodingKeys: String, CodingKey {
    case id, name, coordinate, modes, walkMinutes, walkFromLocation, hideUnreachable, shown,
      excludedQuays, excludedLines
  }

  public init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    id = try values.decode(String.self, forKey: .id)
    name = try values.decode(String.self, forKey: .name)
    coordinate = try values.decode(Coordinate.self, forKey: .coordinate)
    modes = try values.decodeIfPresent([TransportMode].self, forKey: .modes) ?? []
    walkMinutes = try values.decodeIfPresent(Int.self, forKey: .walkMinutes) ?? walkMinutes
    walkFromLocation =
      try values.decodeIfPresent(Bool.self, forKey: .walkFromLocation) ?? walkFromLocation
    hideUnreachable =
      try values.decodeIfPresent(Bool.self, forKey: .hideUnreachable) ?? hideUnreachable
    shown = try values.decodeIfPresent(Int.self, forKey: .shown) ?? shown
    excludedQuays = try values.decodeIfPresent(Set<String>.self, forKey: .excludedQuays) ?? []
    excludedLines = try values.decodeIfPresent(Set<String>.self, forKey: .excludedLines) ?? []
  }
}

public struct NearbySettings: Codable, Equatable, Sendable {
  public static let radiusRange = 100...1000
  public static let stopsRange = 1...5
  public static let perStopRange = 1...8

  public var enabled = true
  public var radius = 500
  public var stops = 3
  public var perStop = 3
  public var modes: Set<TransportMode> = [.metro, .tram, .bus]

  public init() {}

  private enum CodingKeys: String, CodingKey {
    case enabled, radius, stops, perStop, modes
  }

  public init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    enabled = try values.decodeIfPresent(Bool.self, forKey: .enabled) ?? enabled
    radius = try values.decodeIfPresent(Int.self, forKey: .radius) ?? radius
    stops = try values.decodeIfPresent(Int.self, forKey: .stops) ?? stops
    perStop = try values.decodeIfPresent(Int.self, forKey: .perStop) ?? perStop
    modes = try values.decodeIfPresent(Set<TransportMode>.self, forKey: .modes) ?? modes
  }
}

public struct Settings: Codable, Equatable, Sendable {
  public static let key = "settings"
  public static let clockAfterChoices = [5, 10, 15, 20]

  public var favorites: [Favorite] = []
  public var nearby = NearbySettings()
  public var label = MenuBarStyle.next
  public var follow = Follow.nearest
  public var openWith = OpenWith.hover
  public var clockAfter = 10
  public var alertDisruptions = true

  public init() {}

  public var needsLocation: Bool {
    nearby.enabled || favorites.contains(where: \.walkFromLocation)
  }

  private enum CodingKeys: String, CodingKey {
    case favorites, nearby, label, follow, openWith, clockAfter, alertDisruptions
  }

  public init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    favorites = try values.decodeIfPresent([Favorite].self, forKey: .favorites) ?? []
    nearby = try values.decodeIfPresent(NearbySettings.self, forKey: .nearby) ?? nearby
    label = (try? values.decodeIfPresent(MenuBarStyle.self, forKey: .label)) ?? label
    follow = (try? values.decodeIfPresent(Follow.self, forKey: .follow)) ?? follow
    openWith = (try? values.decodeIfPresent(OpenWith.self, forKey: .openWith)) ?? openWith
    clockAfter = try values.decodeIfPresent(Int.self, forKey: .clockAfter) ?? clockAfter
    alertDisruptions =
      try values.decodeIfPresent(Bool.self, forKey: .alertDisruptions) ?? alertDisruptions
  }

  public static func load(from defaults: UserDefaults) -> Settings {
    defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(Settings.self, from: $0) }
      ?? Settings()
  }

  public func save(to defaults: UserDefaults) {
    guard let data = try? JSONEncoder().encode(self) else { return }
    defaults.set(data, forKey: Self.key)
  }
}
