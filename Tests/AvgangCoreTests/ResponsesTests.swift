import Foundation
import Testing

@testable import AvgangCore

struct ResponsesTests {
  @Test func departuresKeepTheOperatorColoursAndPlatform() throws {
    let boards = try Responses.departures(from: try fixture("departures"))
    let first = try #require(boards["NSR:StopPlace:58381"]?.first)
    #expect(boards["NSR:StopPlace:58381"]?.count == 30)
    #expect(
      first.line
        == Line(id: "RUT:Line:46", code: "46", mode: .bus, colour: "E60000", textColour: "FFFFFF"))
    #expect(first.quayID == "NSR:Quay:8076")
    #expect(first.platform == "G")
    #expect(first.destination == "Ullerntoppen")
    #expect(first.realtime)
    #expect(first.expected.timeIntervalSince(first.aimed) == 60)
  }

  @Test func delaysUnderAMinuteShowNoMarker() throws {
    let osloS = try #require(
      try Responses.departures(from: try fixture("departures"))["NSR:StopPlace:59872"])
    let kongsvinger = try #require(
      osloS.first { $0.line.code == "R14" && $0.destination == "Kongsvinger" })
    let asker = try #require(osloS.first { $0.line.code == "R14" && $0.destination == "Asker" })
    #expect(kongsvinger.delayMinutes == 0)
    #expect(asker.delayMinutes == 6)
  }

  @Test func noticesPickTheUserLanguage() throws {
    let osloS = try #require(
      try Responses.departures(from: try fixture("departures"))["NSR:StopPlace:59872"])
    let notice = try #require(osloS.first?.notices.first)
    #expect(notice.text(norwegian: true) == "Stopper ekstra på Stryken")
    #expect(notice.text(norwegian: false) == "Extra stop at Stryken")
    #expect(["xx": "Only"].text(norwegian: false) == "Only")
  }

  @Test func nearbyStopsCarryTheirModes() throws {
    let stops = try Responses.nearby(from: try fixture("nearest"))
    #expect(
      stops.map(\.id) == ["NSR:StopPlace:58381", "NSR:StopPlace:58354", "NSR:StopPlace:58403"])
    #expect(stops.first?.modes == [.bus, .tram, .metro])
  }

  @Test func platformsSkipQuaysWithoutDeparturesAndKeyOnQuayID() throws {
    let platforms = try Responses.platforms(from: try fixture("quays"))
    #expect(platforms.count == 11)
    #expect(platforms.allSatisfy { !$0.destinations.isEmpty })
    #expect(Set(platforms.map(\.id)).count == platforms.count)
    let metroEast = try #require(platforms.first { $0.id == "NSR:Quay:8027" })
    #expect(metroEast.code == "1")
    #expect(metroEast.lines.map(\.code) == ["1", "2", "3", "4", "5"])
  }

  @Test func searchReadsNameLocalityAndCoordinates() throws {
    let matches = try Responses.matches(from: try fixture("search"))
    let first = try #require(matches.first)
    #expect(matches.count == 3)
    #expect(first.id == "NSR:StopPlace:58381")
    #expect(first.name == "Majorstuen")
    #expect(first.locality == "Oslo")
    #expect(first.coordinate == majorstuen)
    #expect(first.modes == [.metro, .tram, .bus])
  }

  @Test func garbageAndMissingDataAreDecodingErrors() {
    #expect(throws: EnturError.decoding) { try Responses.departures(from: Data("nope".utf8)) }
    #expect(throws: EnturError.decoding) {
      try Responses.departures(from: Data(#"{"data":null,"errors":[{}]}"#.utf8))
    }
    #expect(throws: EnturError.decoding) { try Responses.matches(from: Data("[]".utf8)) }
  }

  @Test func unknownModesDecodeLeniently() throws {
    let modes = try JSONDecoder().decode(
      [TransportMode].self, from: Data(#"["metro","hovercraft"]"#.utf8))
    #expect(modes == [.metro, .unknown])
  }
}
