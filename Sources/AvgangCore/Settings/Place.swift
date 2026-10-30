import Foundation

public struct Place: Codable, Equatable, Sendable, Identifiable {
  public static let radiusRange = 100...2000

  public let id: String
  public var name: String
  public var coordinate: Coordinate
  public var radius = 500
  public var stops: Set<String> = []

  public init(name: String, coordinate: Coordinate, id: String = UUID().uuidString) {
    self.id = id
    self.name = name
    self.coordinate = coordinate
  }

  public func distance(to location: Coordinate) -> Double {
    coordinate.distance(to: location)
  }

  private enum CodingKeys: String, CodingKey {
    case id, name, coordinate, radius, stops
  }

  public init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    id = try values.decode(String.self, forKey: .id)
    name = try values.decode(String.self, forKey: .name)
    coordinate = try values.decode(Coordinate.self, forKey: .coordinate)
    radius = try values.decodeIfPresent(Int.self, forKey: .radius) ?? radius
    stops = try values.decodeIfPresent(Set<String>.self, forKey: .stops) ?? []
  }
}
