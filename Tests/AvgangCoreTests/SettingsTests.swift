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
  }
}
