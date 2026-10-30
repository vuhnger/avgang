import Foundation

public enum TravelAlert: Equatable, Sendable {
  case leave(Departure, stop: String)
  case cancelled(Departure, stop: String)
  case disruption(Notice, stop: String)
}
