import Foundation
import Testing

@testable import AvgangCore

struct SettingsTests {
  @Test func anEmptyObjectGivesTheDefaults() throws {
    let settings = try JSONDecoder().decode(Settings.self, from: Data("{}".utf8))
    #expect(settings == Settings())
    #expect(settings.label == .next)
    #expect(settings.follow == .nearest)
    #expect(settings.clockAfter == 10)
    #expect(settings.alertDisruptions)
    #expect(settings.places.isEmpty)
    #expect(settings.nearby.modes == [.metro, .tram, .bus])
  }

  @Test func olderFavoritesKeepTheirStopWhenFieldsAreMissing() throws {
    let json = #"""
      {"favorites":[{"id":"NSR:StopPlace:58381","name":"Majorstuen","coordinate":{"latitude":59.9,"longitude":10.7}}],
       "label":"somethingNew","nearby":{"radius":800}}
      """#
    let settings = try JSONDecoder().decode(Settings.self, from: Data(json.utf8))
    #expect(settings.favorites.map(\.id) == ["NSR:StopPlace:58381"])
    #expect(settings.favorites.first?.walkMinutes == 5)
    #expect(settings.favorites.first?.hideUnreachable == true)
    #expect(settings.favorites.first?.walkFromLocation == false)
    #expect(settings.label == .next)
    #expect(settings.nearby.radius == 800)
    #expect(settings.nearby.enabled)
  }

  @Test func roundTripsThroughDefaults() throws {
    let name = "SettingsTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    #expect(Settings.load(from: defaults) == Settings())
    var custom = Settings()
    custom.favorites = [favorite("a", walk: 7)]
    custom.favorites[0].excludedLines = ["RUT:Line:4"]
    custom.favorites[0].walkFromLocation = true
    custom.label = .leave
    custom.save(to: defaults)
    #expect(Settings.load(from: defaults) == custom)
  }

  @Test func locationIsNeededForNearbyOrALocationBasedWalk() {
    var custom = Settings()
    #expect(custom.needsLocation)
    custom.nearby.enabled = false
    custom.favorites = [favorite("a")]
    #expect(!custom.needsLocation)
    custom.favorites[0].walkFromLocation = true
    #expect(custom.needsLocation)
    custom.favorites[0].walkFromLocation = false
    custom.places = [Place(name: "Home", coordinate: majorstuen)]
    #expect(custom.needsLocation)
  }

  @Test func newFavoritesWalkFromYourLocation() {
    let match = StopMatch(
      id: "a", name: "a", locality: nil, coordinate: majorstuen, modes: [.metro])
    #expect(Favorite(match: match, from: nil).walkFromLocation)
  }

  @Test func removingAFavoriteTakesItOutOfEveryPlace() {
    var custom = Settings()
    custom.favorites = [favorite("a"), favorite("b")]
    var home = Place(name: "Home", coordinate: majorstuen)
    home.stops = ["a", "b"]
    var work = Place(name: "Work", coordinate: majorstuen)
    work.stops = ["a"]
    custom.places = [home, work]
    custom.removeFavorite(at: 0)
    #expect(custom.favorites.map(\.id) == ["b"])
    #expect(custom.places.map(\.stops) == [["b"], []])
  }
}

struct PlaceStopTests {
  private let work = north(of: majorstuen, meters: 3000)

  private func settings() -> Settings {
    var settings = Settings()
    settings.places = [Place(name: "Work", coordinate: work, id: "work")]
    return settings
  }

  private func match(_ id: String, meters: Double) -> StopMatch {
    StopMatch(
      id: id, name: id, locality: nil, coordinate: north(of: work, meters: meters),
      modes: [.bus])
  }

  @Test func addingAStopToAPlaceMakesItAFavoriteWalkedFromThePlace() {
    var chosen = settings()
    chosen.add(match("s", meters: 640), toPlace: "work")
    chosen.add(match("s", meters: 640), toPlace: "work")
    #expect(chosen.favorites.map(\.id) == ["s"])
    #expect(chosen.favorites.first?.walkMinutes == 10)
    #expect(chosen.places.first?.stops == ["s"])
  }

  @Test func adoptsTheClosestStopInsideTheRadius() {
    var chosen = settings()
    let stops = [
      NearbyStop(id: "far", name: "far", coordinate: north(of: work, meters: 300), modes: [.bus]),
      NearbyStop(id: "near", name: "near", coordinate: north(of: work, meters: 80), modes: [.bus]),
    ]
    chosen.adoptClosest(of: stops, forPlace: "work")
    #expect(chosen.places.first?.stops == ["near"])
    chosen.adoptClosest(
      of: [NearbyStop(id: "x", name: "x", coordinate: work, modes: [.bus])], forPlace: "work")
    #expect(chosen.places.first?.stops == ["near"])
  }

  @Test func adoptsNothingOutsideTheRadius() {
    var chosen = settings()
    let outside = NearbyStop(
      id: "out", name: "out", coordinate: north(of: work, meters: 600), modes: [.bus])
    chosen.adoptClosest(of: [outside], forPlace: "work")
    #expect(chosen.places.first?.stops.isEmpty == true)
    #expect(chosen.favorites.isEmpty)
  }

  @Test func movingAPlaceDropsStopsOutsideTheRadius() {
    var chosen = settings()
    chosen.add(match("near", meters: 100), toPlace: "work")
    chosen.add(match("far", meters: 450), toPlace: "work")
    chosen.move(place: "work", to: north(of: work, meters: -100))
    #expect(chosen.places.first?.stops == ["near"])
    #expect(chosen.places.first?.coordinate == north(of: work, meters: -100))
    #expect(chosen.favorites.map(\.id) == ["near", "far"])
  }

  @Test func insideAPlaceItsStopsWalkFromThePlace() {
    var chosen = settings()
    chosen.add(match("s", meters: 640), toPlace: "work")
    let stop = chosen.favorites[0]
    let atDesk = north(of: work, meters: 300)
    #expect(chosen.walk(for: stop, from: atDesk) == 10)
    let away = north(of: work, meters: -1500)
    #expect(chosen.walk(for: stop, from: away) == stop.walk(from: away))
  }

  @Test func manualWalkingTimeIgnoresThePlace() {
    var chosen = settings()
    chosen.add(match("s", meters: 640), toPlace: "work")
    chosen.favorites[0].walkFromLocation = false
    chosen.favorites[0].walkMinutes = 3
    #expect(chosen.walk(for: chosen.favorites[0], from: work) == 3)
  }
}
