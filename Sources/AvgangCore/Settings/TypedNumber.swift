import Foundation

extension ClosedRange where Bound == Int {
  public func number(typed text: String) -> Int? {
    Int(text.trimmingCharacters(in: .whitespaces))
  }

  public func clamped(typed text: String, otherwise fallback: Int) -> Int {
    guard let number = number(typed: text) else { return fallback }
    return Swift.min(Swift.max(number, lowerBound), upperBound)
  }
}
