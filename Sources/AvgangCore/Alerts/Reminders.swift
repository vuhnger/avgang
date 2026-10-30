import Foundation

public struct Reminder: Equatable, Sendable {
  public let stopID: String
  public let stop: String
  public let walkMinutes: Int
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

  public static func armable(_ departure: Departure, walkMinutes: Int, now: Date) -> Bool {
    !departure.cancelled
      && departure.leaves(walkMinutes: max(walkMinutes, shortestLead)) > now
  }

  public static func check(
    _ reminders: [String: Reminder], departures: [String: [Departure]], now: Date
  ) -> (alerts: [TravelAlert], remaining: [String: Reminder]) {
    var alerts: [TravelAlert] = []
    var remaining: [String: Reminder] = [:]
    for (id, reminder) in reminders.sorted(by: { $0.value.leaves < $1.value.leaves }) {
      var reminder = reminder
      reminder.departure = departures[reminder.stopID]?.first { $0.id == id } ?? reminder.departure
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
