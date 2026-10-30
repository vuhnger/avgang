import Testing

@testable import AvgangCore

struct RGBTests {
  @Test func readsOperatorHex() {
    #expect(RGB(hex: "E60000") == RGB(red: 230 / 255, green: 0, blue: 0))
    #expect(RGB(hex: "#ff5959") == RGB(red: 1, green: 89 / 255, blue: 89 / 255))
  }

  @Test func rejectsAnythingElse() {
    #expect(RGB(hex: nil) == nil)
    #expect(RGB(hex: "") == nil)
    #expect(RGB(hex: "E6000") == nil)
    #expect(RGB(hex: "+E6000") == nil)
    #expect(RGB(hex: "GG0000") == nil)
  }
}
