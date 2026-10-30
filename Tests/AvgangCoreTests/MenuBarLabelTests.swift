import Foundation
import Testing

@testable import AvgangCore

private func section(walk: Int, _ departures: [Departure]) -> BoardSection {
  BoardSection(
    id: "s", name: "s", origin: .favorite, modes: [.metro], walkMinutes: walk, distance: nil,
    departures: departures)
}

struct MenuBarLabelTests {
  @Test func nextShowsTheLineAndCountdown() {
    let label = MenuBarLabel(
      style: .next, followed: section(walk: 0, [departure("3", in: 5)]), now: t0, clockAfter: 10)
    #expect(label == .next(line: "3", countdown: .minutes(5)))
  }

  @Test func leaveSubtractsTheWalk() {
    let label = MenuBarLabel(
      style: .leave, followed: section(walk: 4, [departure("3", in: 5)]), now: t0, clockAfter: 10)
    #expect(label == .leave(.minutes(1)))
  }

  @Test func skipsCancelledAndUncatchableDepartures() {
    let label = MenuBarLabel(
      style: .next,
      followed: section(
        walk: 3,
        [departure("1", in: 2), departure("2", in: 4, cancelled: true), departure("3", in: 7)]),
      now: t0, clockAfter: 10)
    #expect(label == .next(line: "3", countdown: .minutes(7)))
  }

  @Test func fallsBackToTheIcon() {
    #expect(MenuBarLabel(style: .next, followed: nil, now: t0, clockAfter: 10) == .icon)
    #expect(
      MenuBarLabel(style: .leave, followed: section(walk: 0, []), now: t0, clockAfter: 10) == .icon)
    #expect(
      MenuBarLabel(
        style: .icon, followed: section(walk: 0, [departure("3", in: 5)]), now: t0, clockAfter: 10)
        == .icon)
  }
}

struct PollPolicyTests {
  @Test func pollsFastOnlyWhileSomethingCountsDown() {
    #expect(PollPolicy.delay(after: nil, failures: 0, active: true, jitter: 0) == 30)
    #expect(PollPolicy.delay(after: nil, failures: 0, active: false, jitter: 0) == 300)
  }

  @Test func waitsOutTheRateLimitWindow() {
    #expect(PollPolicy.delay(after: .rateLimited, failures: 3, active: true, jitter: 1) == 120)
    #expect(!PollPolicy.allowsForcedPoll(after: .rateLimited))
    #expect(PollPolicy.allowsForcedPoll(after: .transport))
  }

  @Test func backsOffExponentiallyWithBoundedJitter() {
    #expect(PollPolicy.delay(after: .transport, failures: 1, active: true, jitter: 0) == 5)
    #expect(PollPolicy.delay(after: .server(500), failures: 3, active: true, jitter: 0) == 20)
    #expect(PollPolicy.delay(after: .decoding, failures: 20, active: true, jitter: 0) == 300)
    #expect(PollPolicy.delay(after: .transport, failures: 1, active: true, jitter: 9) == 6.25)
    #expect(PollPolicy.delay(after: .transport, failures: 1, active: true, jitter: .nan) == 5)
  }
}
