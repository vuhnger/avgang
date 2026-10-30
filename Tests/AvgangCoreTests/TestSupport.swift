import Foundation
import Testing

@testable import AvgangCore

let t0 = Date(timeIntervalSince1970: 1_800_000_000)

func at(_ minutes: Double) -> Date {
  t0.addingTimeInterval(minutes * 60)
}

func fixture(_ name: String) throws -> Data {
  let url = try #require(
    Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
  return try Data(contentsOf: url)
}

let majorstuen = Coordinate(latitude: 59.929213, longitude: 10.71634)

func north(of origin: Coordinate, meters: Double) -> Coordinate {
  Coordinate(latitude: origin.latitude + meters / 111_320, longitude: origin.longitude)
}

func line(_ code: String, mode: TransportMode = .metro) -> Line {
  Line(id: "RUT:Line:\(code)", code: code, mode: mode)
}

func departure(
  _ code: String, in minutes: Double, mode: TransportMode = .metro, quay: String = "Q1",
  delay: Double = 0, cancelled: Bool = false
) -> Departure {
  Departure(
    id: "\(code)-\(minutes)-\(quay)", line: line(code, mode: mode), destination: "Somewhere",
    quayID: quay, platform: "1", aimed: at(minutes - delay), expected: at(minutes),
    realtime: true, cancelled: cancelled)
}

func favorite(
  _ id: String = "NSR:StopPlace:1", at coordinate: Coordinate = majorstuen, walk: Int = 0,
  shown: Int = 5
) -> Favorite {
  var favorite = Favorite(
    match: StopMatch(id: id, name: id, locality: nil, coordinate: coordinate, modes: [.metro]),
    from: nil)
  favorite.walkMinutes = walk
  favorite.shown = shown
  return favorite
}

func stop(_ id: String, meters: Double, modes: [TransportMode] = [.bus]) -> NearbyStop {
  NearbyStop(id: id, name: id, coordinate: north(of: majorstuen, meters: meters), modes: modes)
}
