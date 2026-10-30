import Foundation

public enum TransportMode: String, Codable, Sendable, CaseIterable {
  case metro
  case tram
  case bus
  case rail
  case water
  case coach
  case air
  case cableway
  case funicular
  case lift
  case unknown

  public static let pickable: [TransportMode] = [.metro, .tram, .bus, .rail, .water]

  public init(from decoder: any Decoder) throws {
    let raw = try decoder.singleValueContainer().decode(String.self)
    self = TransportMode(rawValue: raw) ?? .unknown
  }
}
