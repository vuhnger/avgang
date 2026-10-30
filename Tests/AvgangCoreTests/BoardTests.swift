import Foundation
import Testing

@testable import AvgangCore

private func settings(favorites: [Favorite] = [], nearby: Bool = true) -> Settings {
  var settings = Settings()
  settings.favorites = favorites
  settings.nearby.enabled = nearby
  return settings
}

struct FavoriteBoardTests {
  @Test func hidesExcludedPlatformsAndLines() {
    var home = favorite()
    home.excludedQuays = ["Q2"]
    home.excludedLines = ["RUT:Line:4"]
    let sections = Board.sections(
      settings: settings(favorites: [home]),
      departures: [
        home.id: [departure("3", in: 2), departure("5", in: 3, quay: "Q2"), departure("4", in: 4)]
      ],
      nearby: [], location: nil, now: t0)
    #expect(sections.first?.departures.map(\.line.code) == ["3"])
  }

  @Test func hidesWhatYouCannotReachOnFoot() {
    let home = favorite(walk: 4)
    let sections = Board.sections(
      settings: settings(favorites: [home]),
      departures: [
        home.id: [departure("3", in: 3.9), departure("5", in: 4), departure("1", in: 9)]
      ],
      nearby: [], location: nil, now: t0)
    #expect(sections.first?.departures.map(\.line.code) == ["5", "1"])
  }

  @Test func showsUnreachableWhenAskedButNeverDeparted() {
    var home = favorite(walk: 4)
    home.hideUnreachable = false
    let sections = Board.sections(
      settings: settings(favorites: [home]),
      departures: [home.id: [departure("2", in: -0.5), departure("3", in: 1)]],
      nearby: [], location: nil, now: t0)
    #expect(sections.first?.departures.map(\.line.code) == ["3"])
  }

  @Test func capsRowsAtTheChosenCount() {
    let home = favorite(shown: 2)
    let sections = Board.sections(
      settings: settings(favorites: [home]),
      departures: [home.id: (1...6).map { departure("\($0)", in: Double($0)) }],
      nearby: [], location: nil, now: t0)
    #expect(sections.first?.departures.count == 2)
  }

  @Test func keepsAFavoriteWithoutDataYet() {
    let sections = Board.sections(
      settings: settings(favorites: [favorite()]), departures: [:], nearby: [], location: nil,
      now: t0)
    #expect(sections.count == 1)
    #expect(sections.first?.departures.isEmpty == true)
  }
}

struct NearbyBoardTests {
  private let stops = [
    stop("far", meters: 450), stop("close", meters: 120), stop("out", meters: 700),
  ]

  private func board(_ settings: Settings, departures: [String: [Departure]]? = nil)
    -> [BoardSection]
  {
    Board.sections(
      settings: settings,
      departures: departures
        ?? Dictionary(
          uniqueKeysWithValues: stops.map { ($0.id, [departure("20", in: 12, mode: .bus)]) }),
      nearby: stops, location: majorstuen, now: t0)
  }

  @Test func listsStopsInsideTheRadiusClosestFirst() {
    let sections = board(settings())
    #expect(sections.map(\.id) == ["close", "far"])
    #expect(sections.first?.origin == .nearby)
    #expect(sections.first?.walkMinutes == 2)
  }

  @Test func showsAFavoriteInsideTheRadiusOnce() {
    let sections = board(settings(favorites: [favorite("close", at: stops[1].coordinate)]))
    #expect(sections.map(\.id) == ["close", "far"])
    #expect(sections.first?.origin == .favorite)
  }

  @Test func dropsModesYouExcluded() {
    var only = settings()
    only.nearby.modes = [.metro]
    #expect(board(only).isEmpty)
  }

  @Test func dropsStopsWithNothingToCatch() {
    let sections = board(
      settings(),
      departures: [
        "close": [departure("20", in: 1, mode: .bus)], "far": [departure("20", in: 12, mode: .bus)],
      ])
    #expect(sections.map(\.id) == ["far"])
  }

  @Test func respectsStopAndRowLimits() {
    var few = settings()
    few.nearby.stops = 1
    few.nearby.perStop = 1
    let sections = board(
      few,
      departures: [
        "close": [departure("20", in: 10, mode: .bus), departure("21", in: 11, mode: .bus)]
      ])
    #expect(sections.map(\.id) == ["close"])
    #expect(sections.first?.departures.count == 1)
  }

  @Test func needsLocationAndTheSwitch() {
    #expect(board(settings(nearby: false)).isEmpty)
    #expect(
      Board.sections(settings: settings(), departures: [:], nearby: stops, location: nil, now: t0)
        .isEmpty)
  }

  @Test func fetchesFavoritesThenTheClosestCandidates() {
    var limited = settings(favorites: [favorite("home")])
    limited.nearby.stops = 1
    let many = (1...8).map { stop("s\($0)", meters: Double($0) * 50) }
    #expect(
      Board.fetchIDs(settings: limited, nearby: many, location: majorstuen) == [
        "home", "s1", "s2", "s3", "s4",
      ])
    #expect(Board.fetchIDs(settings: limited, nearby: many, location: nil) == ["home"])
  }
}

struct FollowTests {
  private let nearbyStop = stop("near", meters: 100)
  private let homeFar = favorite("home", at: north(of: majorstuen, meters: 3000))
  private let work = favorite("work", at: north(of: majorstuen, meters: 300))

  private func sections(_ settings: Settings, location: Coordinate? = majorstuen) -> [BoardSection]
  {
    Board.sections(
      settings: settings, departures: ["near": [departure("20", in: 12, mode: .bus)]],
      nearby: [nearbyStop], location: location, now: t0)
  }

  @Test func firstFavoriteAlwaysFollowsTheTopOfTheList() {
    var chosen = settings(favorites: [homeFar, work])
    chosen.follow = .firstFavorite
    #expect(Board.followed(sections(chosen), settings: chosen)?.id == "home")
  }

  @Test func nearestPrefersAFavoriteInsideTheRadius() {
    let chosen = settings(favorites: [homeFar, work])
    #expect(Board.followed(sections(chosen), settings: chosen)?.id == "work")
  }

  @Test func nearestFallsBackToTheClosestStop() {
    let chosen = settings(favorites: [homeFar])
    #expect(Board.followed(sections(chosen), settings: chosen)?.id == "near")
  }

  @Test func nearestWithoutLocationFollowsTheFirstFavorite() {
    let chosen = settings(favorites: [homeFar, work])
    #expect(Board.followed(sections(chosen, location: nil), settings: chosen)?.id == "home")
  }
}
