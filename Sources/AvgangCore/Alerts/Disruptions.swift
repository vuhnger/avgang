import Foundation

public enum Disruptions {
  static let memory: TimeInterval = 24 * 60 * 60

  public static func fresh(
    in sections: [BoardSection], seen: inout [String: Date], now: Date
  ) -> [TravelAlert] {
    var alerts: [TravelAlert] = []
    for section in sections where section.origin == .favorite {
      for notice in section.departures.flatMap(\.notices) {
        if seen[notice.id] == nil { alerts.append(.disruption(notice, stop: section.name)) }
        seen[notice.id] = now
      }
    }
    seen = seen.filter { now.timeIntervalSince($0.value) < memory }
    return alerts
  }
}
