import Foundation

enum Responses {
  private struct Envelope<Payload: Decodable>: Decodable {
    let data: Payload?
  }

  private struct Presentation: Decodable {
    let colour: String?
    let textColour: String?
  }

  private struct RawLine: Decodable {
    let id: String
    let publicCode: String?
    let transportMode: TransportMode?
    let presentation: Presentation?

    var line: Line {
      Line(
        id: id, code: publicCode ?? "", mode: transportMode ?? .unknown,
        colour: presentation?.colour, textColour: presentation?.textColour)
    }
  }

  private struct Destination: Decodable {
    let frontText: String?
  }

  private struct Text: Decodable {
    let value: String
    let language: String?
  }

  private struct Situation: Decodable {
    let summary: [Text]
  }

  private struct Call: Decodable {
    struct Quay: Decodable {
      let id: String
      let publicCode: String?
    }

    struct Journey: Decodable {
      let id: String
      let line: RawLine
    }

    let aimedDepartureTime: Date
    let expectedDepartureTime: Date
    let realtime: Bool
    let cancellation: Bool
    let destinationDisplay: Destination?
    let quay: Quay
    let serviceJourney: Journey
    let situations: [Situation]

    var departure: Departure {
      Departure(
        id: "\(serviceJourney.id)|\(quay.id)|\(aimedDepartureTime.timeIntervalSince1970)",
        line: serviceJourney.line.line,
        destination: destinationDisplay?.frontText ?? "",
        quayID: quay.id,
        platform: quay.publicCode.flatMap { $0.isEmpty ? nil : $0 },
        aimed: aimedDepartureTime,
        expected: expectedDepartureTime,
        realtime: realtime,
        cancelled: cancellation,
        notices: situations.map { situation in
          Dictionary(
            situation.summary.map { ($0.language ?? "", $0.value) }, uniquingKeysWith: { a, _ in a }
          )
        })
    }
  }

  private struct StopCalls: Decodable {
    let id: String
    let estimatedCalls: [Call]
  }

  private struct DeparturesData: Decodable {
    let stopPlaces: [StopCalls?]
  }

  private struct NearestData: Decodable {
    struct Place: Decodable {
      let id: String?
      let name: String?
      let latitude: Double?
      let longitude: Double?
      let transportMode: [TransportMode]?
    }

    struct Edge: Decodable {
      struct Node: Decodable { let place: Place? }
      let node: Node
    }

    struct Connection: Decodable { let edges: [Edge] }

    let nearest: Connection?
  }

  private struct PlatformsData: Decodable {
    struct Quay: Decodable {
      struct Call: Decodable { let destinationDisplay: Destination? }
      let id: String
      let publicCode: String?
      let lines: [RawLine]
      let estimatedCalls: [Call]
    }

    struct Stop: Decodable { let quays: [Quay] }

    let stopPlace: Stop?
  }

  private struct Search: Decodable {
    struct Feature: Decodable {
      struct Geometry: Decodable { let coordinates: [Double] }
      struct Properties: Decodable {
        struct Names: Decodable { let `default`: String? }
        struct Address: Decodable { let locality: String? }
        struct Mode: Decodable { let mode: TransportMode }
        let id: String
        let names: Names?
        let name: String?
        let address: Address?
        let transportModes: [Mode]?
      }
      let geometry: Geometry
      let properties: Properties
    }

    let features: [Feature]
  }

  private static let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }()

  private static func decode<Payload: Decodable>(_ type: Payload.Type, from data: Data) throws
    -> Payload
  {
    guard let envelope = try? decoder.decode(Envelope<Payload>.self, from: data),
      let payload = envelope.data
    else { throw EnturError.decoding }
    return payload
  }

  static func departures(from data: Data) throws -> [String: [Departure]] {
    let payload = try decode(DeparturesData.self, from: data)
    return Dictionary(
      payload.stopPlaces.compactMap { $0 }.map {
        ($0.id, $0.estimatedCalls.map(\.departure).sorted { $0.expected < $1.expected })
      },
      uniquingKeysWith: { a, _ in a })
  }

  static func nearby(from data: Data) throws -> [NearbyStop] {
    let payload = try decode(NearestData.self, from: data)
    var seen = Set<String>()
    return (payload.nearest?.edges ?? []).compactMap { edge in
      guard let place = edge.node.place, let id = place.id, let name = place.name,
        let latitude = place.latitude, let longitude = place.longitude,
        seen.insert(id).inserted
      else { return nil }
      return NearbyStop(
        id: id, name: name, coordinate: Coordinate(latitude: latitude, longitude: longitude),
        modes: unique(place.transportMode ?? []))
    }
  }

  static func platforms(from data: Data) throws -> [Platform] {
    let payload = try decode(PlatformsData.self, from: data)
    return (payload.stopPlace?.quays ?? []).compactMap { quay in
      guard !quay.estimatedCalls.isEmpty else { return nil }
      let destinations = unique(quay.estimatedCalls.compactMap(\.destinationDisplay?.frontText))
      let lines = unique(quay.lines.map(\.line))
        .sorted { $0.code.localizedStandardCompare($1.code) == .orderedAscending }
      return Platform(
        id: quay.id, code: quay.publicCode.flatMap { $0.isEmpty ? nil : $0 },
        destinations: destinations, lines: lines)
    }
    .sorted { ($0.code ?? "~").localizedStandardCompare($1.code ?? "~") == .orderedAscending }
  }

  static func matches(from data: Data) throws -> [StopMatch] {
    guard let search = try? decoder.decode(Search.self, from: data) else {
      throw EnturError.decoding
    }
    return search.features.compactMap { feature in
      let properties = feature.properties
      guard feature.geometry.coordinates.count >= 2,
        let name = properties.names?.default ?? properties.name
      else { return nil }
      return StopMatch(
        id: properties.id, name: name, locality: properties.address?.locality,
        coordinate: Coordinate(
          latitude: feature.geometry.coordinates[1], longitude: feature.geometry.coordinates[0]),
        modes: unique((properties.transportModes ?? []).map(\.mode)))
    }
  }

  private static func unique<Element: Hashable>(_ items: [Element]) -> [Element] {
    var seen = Set<Element>()
    return items.filter { seen.insert($0).inserted }
  }
}
