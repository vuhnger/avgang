import Foundation

public enum MenuBarLabel: Equatable, Sendable {
  case icon
  case next(line: String, countdown: Countdown)
  case leave(Countdown)

  public init(style: LabelStyle, followed: BoardSection?, now: Date, clockAfter: Int) {
    let catchable = followed?.departures.first {
      !$0.cancelled && $0.reachable(walkMinutes: followed?.walkMinutes ?? 0, now: now)
    }
    switch (style, followed, catchable) {
    case (.next, _, let departure?):
      self = .next(
        line: departure.line.code,
        countdown: Countdown(until: departure.expected, now: now, clockAfter: clockAfter))
    case (.leave, let section?, let departure?):
      self = .leave(
        Countdown(
          until: departure.leaves(walkMinutes: section.walkMinutes), now: now,
          clockAfter: clockAfter))
    default:
      self = .icon
    }
  }
}
