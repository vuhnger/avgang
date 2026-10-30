import Foundation
import Testing

@testable import AvgangCore

private func reminder(_ departure: Departure, walk: Int = 5) -> [String: Reminder] {
  [departure.id: Reminder(stopID: "S", stop: "Majorstuen", walkMinutes: walk, departure: departure)]
}

private func moved(_ departure: Departure, to minutes: Double) -> Departure {
  Departure(
    id: departure.id, line: departure.line, destination: departure.destination,
    quayID: departure.quayID, platform: departure.platform, aimed: departure.aimed,
    expected: at(minutes), realtime: true, cancelled: false)
}

private func noticed(_ departure: Departure, _ ids: String...) -> Departure {
  Departure(
    id: departure.id, line: departure.line, destination: departure.destination,
    quayID: departure.quayID, platform: departure.platform, aimed: departure.aimed,
    expected: departure.expected, realtime: departure.realtime, cancelled: departure.cancelled,
    notices: ids.map { Notice(id: $0, summary: ["en": "Notice \($0)"]) })
}

private func section(_ id: String, _ origin: BoardSection.Origin, _ departures: [Departure])
  -> BoardSection
{
  BoardSection(
    id: id, name: id, origin: origin, modes: [.metro], walkMinutes: 0, distance: nil,
    departures: departures)
}

struct ReminderTests {
  @Test func waitsUntilItIsTimeToLeave() {
    let bus = departure("31", in: 12)
    let result = Reminders.check(reminder(bus), departures: ["S": [bus]], walks: [:], now: at(6.9))
    #expect(result.alerts.isEmpty)
    #expect(result.remaining[bus.id] != nil)
  }

  @Test func firesOnceWhenItIsTimeToLeave() {
    let bus = departure("31", in: 12)
    let result = Reminders.check(reminder(bus), departures: ["S": [bus]], walks: [:], now: at(7))
    #expect(result.alerts == [.leave(bus, stop: "Majorstuen")])
    #expect(result.remaining.isEmpty)
  }

  @Test func followsADelay() {
    let bus = departure("31", in: 12)
    let result = Reminders.check(
      reminder(bus), departures: ["S": [moved(bus, to: 15)]], walks: [:], now: at(8))
    #expect(result.alerts.isEmpty)
    #expect(result.remaining[bus.id]?.departure.expected == at(15))
  }

  @Test func warnsWhenTheDepartureIsCancelled() {
    let bus = departure("31", in: 12)
    let cancelled = departure("31", in: 12, cancelled: true)
    let result = Reminders.check(
      reminder(bus), departures: ["S": [cancelled]], walks: [:], now: at(1))
    #expect(result.alerts == [.cancelled(cancelled, stop: "Majorstuen")])
    #expect(result.remaining.isEmpty)
  }

  @Test func dropsADepartureThatAlreadyLeftWithoutAWarning() {
    let bus = departure("31", in: 12)
    let result = Reminders.check(reminder(bus), departures: [:], walks: [:], now: at(12))
    #expect(result.alerts.isEmpty)
    #expect(result.remaining.isEmpty)
  }

  @Test func keepsTheLastKnownTimeWhenTheStopIsNoLongerFetched() {
    let bus = departure("31", in: 12)
    let result = Reminders.check(reminder(bus), departures: [:], walks: [:], now: at(7))
    #expect(result.alerts == [.leave(bus, stop: "Majorstuen")])
  }

  @Test func followsTheWalkingTimeAsYouMove() {
    let bus = departure("31", in: 12)
    let closer = Reminders.check(
      reminder(bus), departures: ["S": [bus]], walks: ["S": 3], now: at(7))
    #expect(closer.alerts.isEmpty)
    #expect(closer.remaining[bus.id]?.walkMinutes == 3)
  }

  @Test func dropsADepartureThatVanishedFromItsStop() {
    let bus = departure("31", in: 12)
    let result = Reminders.check(
      reminder(bus), departures: ["S": [departure("31", in: 20)]], walks: [:], now: at(7))
    #expect(result.alerts.isEmpty)
    #expect(result.remaining.isEmpty)
  }

  @Test func givesAStopAtTheDoorAMinuteOfWarning() {
    let bus = departure("31", in: 12)
    let result = Reminders.check(
      reminder(bus, walk: 0), departures: ["S": [bus]], walks: [:], now: at(11))
    #expect(result.alerts == [.leave(bus, stop: "Majorstuen")])
    #expect(Reminders.armable(bus, walkMinutes: 0, now: at(10.9)))
    #expect(!Reminders.armable(bus, walkMinutes: 0, now: at(11)))
  }

  @Test func cannotArmACancelledOrMissedDeparture() {
    #expect(!Reminders.armable(departure("31", in: 12, cancelled: true), walkMinutes: 5, now: t0))
    #expect(!Reminders.armable(departure("31", in: 4), walkMinutes: 5, now: t0))
    #expect(Reminders.armable(departure("31", in: 6), walkMinutes: 5, now: t0))
  }
}

struct DisruptionTests {
  private let withNotice = [section("Home", .favorite, [noticed(departure("3", in: 2), "N1")])]
  private let quiet = [section("Home", .favorite, [departure("3", in: 2)])]

  @Test func alertsOnceForANewNoticeAtAFavorite() {
    var seen: [String: Date] = [:]
    #expect(
      Disruptions.fresh(in: withNotice, seen: &seen, now: t0) == [
        .disruption(Notice(id: "N1", summary: ["en": "Notice N1"]), stop: "Home")
      ])
    #expect(Disruptions.fresh(in: withNotice, seen: &seen, now: at(1)).isEmpty)
  }

  @Test func ignoresNearbyStops() {
    var seen: [String: Date] = [:]
    let board = [section("Near", .nearby, [noticed(departure("3", in: 2), "N1")])]
    #expect(Disruptions.fresh(in: board, seen: &seen, now: t0).isEmpty)
  }

  @Test func alertsOnceWhenANoticeCoversTwoStops() {
    var seen: [String: Date] = [:]
    let board = [
      section("Home", .favorite, [noticed(departure("3", in: 2), "N1")]),
      section("Work", .favorite, [noticed(departure("5", in: 4), "N1", "N2")]),
    ]
    #expect(Disruptions.fresh(in: board, seen: &seen, now: t0).count == 2)
  }

  @Test func remembersANoticeThatBrieflyLeavesTheBoard() {
    var seen: [String: Date] = [:]
    _ = Disruptions.fresh(in: withNotice, seen: &seen, now: t0)
    _ = Disruptions.fresh(in: quiet, seen: &seen, now: at(60))
    #expect(Disruptions.fresh(in: withNotice, seen: &seen, now: at(120)).isEmpty)
  }

  @Test func forgetsANoticeAfterADayAway() {
    var seen: [String: Date] = [:]
    _ = Disruptions.fresh(in: withNotice, seen: &seen, now: t0)
    _ = Disruptions.fresh(in: quiet, seen: &seen, now: at(24 * 60))
    #expect(seen.isEmpty)
  }
}
