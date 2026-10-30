public struct RGB: Equatable, Sendable {
  public let red: Double
  public let green: Double
  public let blue: Double

  public init(red: Double, green: Double, blue: Double) {
    self.red = red
    self.green = green
    self.blue = blue
  }

  public init?(hex: String?) {
    guard let digits = hex?.trimmingPrefix("#"), digits.count == 6,
      digits.allSatisfy(\.isHexDigit), let value = UInt32(digits, radix: 16)
    else { return nil }
    self.init(
      red: Double(value >> 16 & 0xFF) / 255, green: Double(value >> 8 & 0xFF) / 255,
      blue: Double(value & 0xFF) / 255)
  }
}
