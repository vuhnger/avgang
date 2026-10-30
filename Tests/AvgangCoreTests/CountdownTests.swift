import Foundation
import Testing

@testable import AvgangCore

struct CountdownTests {
  @Test func underAMinuteIsNow() {
    #expect(Countdown(until: at(0.99), now: t0, clockAfter: 10) == .now)
    #expect(Countdown(until: at(-2), now: t0, clockAfter: 10) == .now)
  }

  @Test func minutesRoundDown() {
    #expect(Countdown(until: at(1), now: t0, clockAfter: 10) == .minutes(1))
    #expect(Countdown(until: at(5.98), now: t0, clockAfter: 10) == .minutes(5))
  }

  @Test func clockTimeStartsAfterTheThreshold() {
    #expect(Countdown(until: at(10.5), now: t0, clockAfter: 10) == .minutes(10))
    #expect(Countdown(until: at(11), now: t0, clockAfter: 10) == .clock(at(11)))
    #expect(Countdown(until: at(6), now: t0, clockAfter: 5) == .clock(at(6)))
  }
}

struct WalkingTests {
  @Test func roundsUpToWholeMinutes() {
    #expect(Walking.minutes(meters: 0) == 0)
    #expect(Walking.minutes(meters: 1) == 1)
    #expect(Walking.minutes(meters: 280) == 5)
  }

  @Test func blurKeepsThreeDecimals() {
    let blurred = Coordinate(latitude: 59.929613, longitude: 10.716342).blurred
    #expect(blurred == Coordinate(latitude: 59.93, longitude: 10.716))
  }

  @Test func newFavoritesEstimateTheWalkFromHere() {
    let match = StopMatch(
      id: "a", name: "a", locality: nil, coordinate: north(of: majorstuen, meters: 640), modes: [])
    #expect(Favorite(match: match, from: majorstuen).walkMinutes == 10)
    #expect(Favorite(match: match, from: nil).walkMinutes == 5)
    #expect(Favorite(match: match, from: north(of: majorstuen, meters: 9000)).walkMinutes == 30)
  }
}
