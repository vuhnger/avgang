import Foundation

public enum EnturError: Error, Equatable, Sendable {
  case rateLimited
  case server(Int)
  case transport
  case decoding
}

public struct EnturClient: Sendable {
  public typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

  public static let clientName = "vuhnger-avgang"
  static let journeyPlanner = URL(string: "https://api.entur.io/journey-planner/v3/graphql")!
  static let geocoder = URL(string: "https://api.entur.io/geocoder/v3/autocomplete")!
  static let timeout: TimeInterval = 15

  private let transport: Transport

  public init(transport: @escaping Transport = EnturClient.live) {
    self.transport = transport
  }

  public static let live: Transport = { request in
    try await session.data(for: request)
  }

  private static let session: URLSession = {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = timeout
    configuration.timeoutIntervalForResource = timeout * 2
    configuration.waitsForConnectivity = false
    return URLSession(configuration: configuration)
  }()

  public func departures(stopIDs: [String]) async throws -> [String: [Departure]] {
    guard !stopIDs.isEmpty else { return [:] }
    let data = try await graphQL(
      Queries.departures, variables: ["ids": stopIDs, "count": Queries.departureCount])
    return try Responses.departures(from: data)
  }

  public func nearby(around coordinate: Coordinate, within meters: Int) async throws -> [NearbyStop]
  {
    let blurred = coordinate.blurred
    let data = try await graphQL(
      Queries.nearest,
      variables: [
        "lat": blurred.latitude, "lon": blurred.longitude,
        "max": meters + Queries.blurSlack, "first": Queries.nearestCount,
      ])
    return try Responses.nearby(from: data)
  }

  public func platforms(stopID: String) async throws -> [Platform] {
    let data = try await graphQL(Queries.platforms, variables: ["id": stopID])
    return try Responses.platforms(from: data)
  }

  public func search(_ text: String, layers: String = "stopPlace") async throws -> [StopMatch] {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count >= 2 else { return [] }
    var components = URLComponents(url: Self.geocoder, resolvingAgainstBaseURL: false)!
    components.queryItems = [
      URLQueryItem(name: "q", value: String(trimmed.prefix(100))),
      URLQueryItem(name: "limit", value: "8"),
      URLQueryItem(name: "layers", value: layers),
    ]
    var request = URLRequest(url: components.url!)
    request.setValue(Self.clientName, forHTTPHeaderField: "ET-Client-Name")
    return try Responses.matches(from: try await send(request))
  }

  private func graphQL(_ query: String, variables: [String: any Sendable]) async throws -> Data {
    var request = URLRequest(url: Self.journeyPlanner)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(Self.clientName, forHTTPHeaderField: "ET-Client-Name")
    request.httpBody = try JSONSerialization.data(
      withJSONObject: ["query": query, "variables": variables])
    return try await send(request)
  }

  private func send(_ request: URLRequest) async throws -> Data {
    var request = request
    request.timeoutInterval = Self.timeout
    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await transport(request)
    } catch is CancellationError {
      throw CancellationError()
    } catch {
      throw EnturError.transport
    }
    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
    switch status {
    case 200..<300: return data
    case 429: throw EnturError.rateLimited
    default: throw EnturError.server(status)
    }
  }
}
