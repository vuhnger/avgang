import Testing

@testable import AvgangCore

struct TypedNumberTests {
  @Test func typedNumbersStayInsideTheRange() {
    #expect(Favorite.walkRange.clamped(typed: "12", otherwise: 5) == 12)
    #expect(Favorite.walkRange.clamped(typed: " 7 ", otherwise: 5) == 7)
    #expect(Favorite.walkRange.clamped(typed: "45", otherwise: 5) == 30)
    #expect(Favorite.shownRange.clamped(typed: "0", otherwise: 5) == 1)
    #expect(Favorite.shownRange.clamped(typed: "-3", otherwise: 5) == 1)
  }

  @Test func textThatIsNotAWholeNumberKeepsTheOldValue() {
    #expect(Favorite.walkRange.clamped(typed: "", otherwise: 5) == 5)
    #expect(Favorite.walkRange.clamped(typed: "2,5", otherwise: 5) == 5)
    #expect(Favorite.walkRange.clamped(typed: "ten", otherwise: 5) == 5)
    #expect(Favorite.walkRange.clamped(typed: "99999999999999999999", otherwise: 5) == 5)
  }
}
