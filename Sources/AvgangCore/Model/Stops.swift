import CoreLocation
import Foundation

public struct Coordinate: Codable, Equatable, Sendable {
  public let latitude: Double
  public let longitude: Double

  public init(latitude: Double, longitude: Double) {
    self.latitude = latitude
    self.longitude = longitude
  }

  public func distance(to other: Coordinate) -> Double {
    CLLocation(latitude: latitude, longitude: longitude)
      .distance(from: CLLocation(latitude: other.latitude, longitude: other.longitude))
  }

  public var blurred: Coordinate {
    Coordinate(
      latitude: (latitude * 1000).rounded() / 1000, longitude: (longitude * 1000).rounded() / 1000)
  }
}

public struct StopMatch: Equatable, Sendable, Identifiable {
  public let id: String
  public let name: String
  public let locality: String?
  public let coordinate: Coordinate
  public let modes: [TransportMode]

  public init(
    id: String, name: String, locality: String?, coordinate: Coordinate, modes: [TransportMode]
  ) {
    self.id = id
    self.name = name
    self.locality = locality
    self.coordinate = coordinate
    self.modes = modes
  }
}

public struct NearbyStop: Equatable, Sendable, Identifiable {
  public let id: String
  public let name: String
  public let coordinate: Coordinate
  public let modes: [TransportMode]

  public init(id: String, name: String, coordinate: Coordinate, modes: [TransportMode]) {
    self.id = id
    self.name = name
    self.coordinate = coordinate
    self.modes = modes
  }
}

public struct Platform: Equatable, Sendable, Identifiable {
  public let id: String
  public let code: String?
  public let destinations: [String]
  public let lines: [Line]
}

public enum Walking {
  public static let straightLineMetersPerMinute = 65.0

  public static func minutes(meters: Double) -> Int {
    Int((meters / straightLineMetersPerMinute).rounded(.up))
  }
}
