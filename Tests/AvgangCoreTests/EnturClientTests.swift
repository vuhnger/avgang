import Foundation
import Synchronization
import Testing

@testable import AvgangCore

private func respond(_ status: Int, _ body: Data = Data(#"{"data":{"stopPlaces":[]}}"#.utf8))
  -> EnturClient.Transport
{
  { request in
    (
      body,
      HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
    )
  }
}

struct EnturClientTests {
  @Test func everyRequestNamesTheClient() async throws {
    let seen = Mutex<[URLRequest]>([])
    let client = EnturClient { request in
      seen.withLock { $0.append(request) }
      return try await respond(200)(request)
    }
    _ = try await client.departures(stopIDs: ["NSR:StopPlace:1"])
    let request = try #require(seen.withLock { $0.first })
    #expect(request.value(forHTTPHeaderField: "ET-Client-Name") == "vuhnger-avgang")
    #expect(request.httpMethod == "POST")
    #expect(request.timeoutInterval == 15)
  }

  @Test func statusCodesMapToErrors() async {
    await #expect(throws: EnturError.rateLimited) {
      try await EnturClient(transport: respond(429)).departures(stopIDs: ["a"])
    }
    await #expect(throws: EnturError.server(503)) {
      try await EnturClient(transport: respond(503)).departures(stopIDs: ["a"])
    }
    await #expect(throws: EnturError.transport) {
      try await EnturClient { _ in throw URLError(.notConnectedToInternet) }.departures(stopIDs: [
        "a"
      ])
    }
  }

  @Test func shortSearchesAndEmptyBoardsSkipTheNetwork() async throws {
    let calls = Mutex(0)
    let client = EnturClient { request in
      calls.withLock { $0 += 1 }
      return try await respond(200)(request)
    }
    #expect(try await client.search(" m ").isEmpty)
    #expect(try await client.departures(stopIDs: []).isEmpty)
    #expect(calls.withLock { $0 } == 0)
  }

  @Test func nearbySendsABlurredLocation() async throws {
    let body = Mutex(Data())
    let client = EnturClient { request in
      body.withLock { $0 = request.httpBody ?? Data() }
      return try await respond(200, try fixture("nearest"))(request)
    }
    _ = try await client.nearby(
      around: Coordinate(latitude: 59.929213, longitude: 10.716342), within: 500)
    let json = try JSONSerialization.jsonObject(with: body.withLock { $0 }) as? [String: Any]
    let variables = try #require(json?["variables"] as? [String: Any])
    #expect(variables["lat"] as? Double == 59.929)
    #expect(variables["lon"] as? Double == 10.716)
    #expect(variables["max"] as? Int == 650)
  }

  @Test func searchSendsABlurredFocus() async throws {
    let url = Mutex<URL?>(nil)
    let client = EnturClient { request in
      url.withLock { $0 = request.url }
      return try await respond(200, Data(#"{"features":[]}"#.utf8))(request)
    }
    _ = try await client.search(
      "Røa", near: Coordinate(latitude: 59.929213, longitude: 10.716342))
    let items = try #require(
      url.withLock { $0 }.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }?
        .queryItems)
    #expect(items.first { $0.name == "lat" }?.value == "59.929")
    #expect(items.first { $0.name == "lon" }?.value == "10.716")
  }
}
