import Foundation

public enum Countdown: Equatable, Sendable {
  case now
  case minutes(Int)
  case clock(Date)

  public init(until date: Date, now: Date, clockAfter: Int) {
    let seconds = date.timeIntervalSince(now)
    guard seconds >= 60 else {
      self = .now
      return
    }
    let minutes = Int(seconds / 60)
    self = minutes <= clockAfter ? .minutes(minutes) : .clock(date)
  }
}
