import Foundation

public enum PollPolicy {
  static let activeInterval: TimeInterval = 30
  static let idleInterval: TimeInterval = 300
  static let rateLimitWindow: TimeInterval = 120
  static let backoffBase: TimeInterval = 5
  static let backoffCap: TimeInterval = 300
  static let jitterShare = 0.25

  public static func delay(after error: EnturError?, failures: Int, active: Bool, jitter: Double)
    -> TimeInterval
  {
    switch error {
    case nil:
      return active ? activeInterval : idleInterval
    case .rateLimited:
      return rateLimitWindow
    case .transport, .server, .decoding:
      let base = min(backoffCap, backoffBase * pow(2, Double(max(0, failures - 1))))
      let spread = jitter.isFinite ? min(max(jitter, 0), 1) : 0
      return base * (1 + jitterShare * spread)
    }
  }

  public static func allowsForcedPoll(after error: EnturError?) -> Bool {
    error != .rateLimited
  }
}
