import Foundation

public struct Reminder: Equatable, Sendable {
  public let stopID: String
  public let stop: String
  public var walkMinutes: Int
  public var departure: Departure

  public init(stopID: String, stop: String, walkMinutes: Int, departure: Departure) {
    self.stopID = stopID
    self.stop = stop
    self.walkMinutes = walkMinutes
    self.departure = departure
  }

  var leaves: Date {
    departure.leaves(walkMinutes: max(walkMinutes, Reminders.shortestLead))
  }
}

public enum Reminders {
  static let shortestLead = 1
  public static let freshFor: TimeInterval = 90

  public static func armable(_ departure: Departure, walkMinutes: Int, now: Date) -> Bool {
    !departure.cancelled
      && departure.leaves(walkMinutes: max(walkMinutes, shortestLead)) > now
  }

  public static func check(
    _ reminders: [String: Reminder], departures: [String: [Departure]], walks: [String: Int],
    now: Date
  ) -> (alerts: [TravelAlert], remaining: [String: Reminder]) {
    var alerts: [TravelAlert] = []
    var remaining: [String: Reminder] = [:]
    for (id, reminder) in reminders.sorted(by: { $0.value.leaves < $1.value.leaves }) {
      var reminder = reminder
      reminder.walkMinutes = walks[reminder.stopID] ?? reminder.walkMinutes
      if let fetched = departures[reminder.stopID] {
        guard let current = fetched.first(where: { $0.id == id }) else { continue }
        reminder.departure = current
      }
      if reminder.departure.cancelled {
        alerts.append(.cancelled(reminder.departure, stop: reminder.stop))
      } else if reminder.departure.expected <= now {
        continue
      } else if reminder.leaves <= now {
        alerts.append(.leave(reminder.departure, stop: reminder.stop))
      } else {
        remaining[id] = reminder
      }
    }
    return (alerts, remaining)
  }
}
