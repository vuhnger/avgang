import Foundation

public struct BoardSection: Equatable, Sendable, Identifiable {
  public enum Origin: Equatable, Sendable {
    case favorite
    case nearby
  }

  public let id: String
  public let name: String
  public let origin: Origin
  public let modes: [TransportMode]
  public let walkMinutes: Int
  public let distance: Int?
  public let departures: [Departure]
}

public enum Board {
  static let spareNearbyStops = 3

  public static func fetchIDs(settings: Settings, nearby: [NearbyStop], location: Coordinate?)
    -> [String]
  {
    settings.favorites.map(\.id)
      + candidates(settings: settings, nearby: nearby, location: location)
      .prefix(settings.nearby.stops + spareNearbyStops).map(\.stop.id)
  }

  public static func sections(
    settings: Settings, departures: [String: [Departure]], nearby: [NearbyStop],
    location: Coordinate?, now: Date
  ) -> [BoardSection] {
    let favorites = settings.favorites.map { favorite in
      let walk = favorite.walk(from: location)
      return BoardSection(
        id: favorite.id, name: favorite.name, origin: .favorite, modes: favorite.modes,
        walkMinutes: walk,
        distance: location.map { Int(favorite.coordinate.distance(to: $0)) },
        departures: Array(
          (departures[favorite.id] ?? [])
            .filter { departure in
              favorite.keeps(departure)
                && (favorite.hideUnreachable
                  ? departure.reachable(walkMinutes: walk, now: now)
                  : departure.expected >= now)
            }
            .prefix(favorite.shown)))
    }
    let close = candidates(settings: settings, nearby: nearby, location: location)
      .compactMap { candidate -> BoardSection? in
        let walk = Walking.minutes(meters: candidate.distance)
        let shown = (departures[candidate.stop.id] ?? []).filter {
          settings.nearby.modes.contains($0.line.mode) && $0.reachable(walkMinutes: walk, now: now)
        }
        guard !shown.isEmpty else { return nil }
        return BoardSection(
          id: candidate.stop.id, name: candidate.stop.name, origin: .nearby,
          modes: candidate.stop.modes, walkMinutes: walk, distance: Int(candidate.distance),
          departures: Array(shown.prefix(settings.nearby.perStop)))
      }
      .prefix(settings.nearby.stops)
    return favorites + close
  }

  public static func followed(_ sections: [BoardSection], settings: Settings) -> BoardSection? {
    let firstFavorite = sections.first { $0.origin == .favorite }
    guard settings.follow == .nearest else { return firstFavorite ?? sections.first }
    let closeFavorite =
      sections
      .filter { $0.origin == .favorite && ($0.distance ?? .max) <= settings.nearby.radius }
      .min { ($0.distance ?? .max) < ($1.distance ?? .max) }
    return closeFavorite ?? sections.first { $0.origin == .nearby } ?? firstFavorite
  }

  private static func candidates(settings: Settings, nearby: [NearbyStop], location: Coordinate?)
    -> [(stop: NearbyStop, distance: Double)]
  {
    guard settings.nearby.enabled, let location else { return [] }
    let favoriteIDs = Set(settings.favorites.map(\.id))
    return
      nearby
      .filter { !favoriteIDs.contains($0.id) && !settings.nearby.modes.isDisjoint(with: $0.modes) }
      .map { (stop: $0, distance: $0.coordinate.distance(to: location)) }
      .filter { $0.distance <= Double(settings.nearby.radius) }
      .sorted { $0.distance < $1.distance }
  }
}
