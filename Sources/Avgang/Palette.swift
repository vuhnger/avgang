import AvgangCore
import SwiftUI

enum Palette {
  static let navy = Color(red: 0x18 / 255, green: 0x1C / 255, blue: 0x56 / 255)
  static let band = Color(red: 0x11 / 255, green: 0x14 / 255, blue: 0x3C / 255)
  static let lavender = Color(red: 0xAE / 255, green: 0xB7 / 255, blue: 0xE2 / 255)
  static let coral = Color(red: 0xFF / 255, green: 0x59 / 255, blue: 0x59 / 255)
  static let canary = Color(red: 0xFF / 255, green: 0xE0 / 255, blue: 0x82 / 255)
  static let rule = Color.white.opacity(0.08)

  static func fill(of line: Line) -> Color {
    RGB(hex: line.colour).map(color) ?? modeColor(line.mode)
  }

  static func ink(of line: Line) -> Color {
    RGB(hex: line.textColour).map(color) ?? (RGB(hex: line.colour) == nil ? navy : .white)
  }

  private static func color(_ rgb: RGB) -> Color {
    Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
  }

  private static func modeColor(_ mode: TransportMode) -> Color {
    switch mode {
    case .metro: Color(red: 0xF0 / 255, green: 0x89 / 255, blue: 0x01 / 255)
    case .tram: Color(red: 0xB4 / 255, green: 0x82 / 255, blue: 0xFB / 255)
    case .bus, .coach: Color(red: 0xFF / 255, green: 0x63 / 255, blue: 0x92 / 255)
    case .rail: Color(red: 0x42 / 255, green: 0xA5 / 255, blue: 0xF5 / 255)
    case .water: Color(red: 0x6F / 255, green: 0xDF / 255, blue: 0xFF / 255)
    default: lavender
    }
  }
}

extension TransportMode {
  var symbol: String {
    switch self {
    case .metro: "tram.fill.tunnel"
    case .tram: "tram.fill"
    case .bus, .coach: "bus.fill"
    case .rail: "train.side.front.car"
    case .water: "ferry.fill"
    case .air: "airplane"
    case .cableway, .funicular, .lift: "cablecar.fill"
    case .unknown: "mappin"
    }
  }

  var title: String {
    switch self {
    case .metro: String(localized: "Metro")
    case .tram: String(localized: "Tram")
    case .bus: String(localized: "Bus")
    case .rail: String(localized: "Train")
    case .water: String(localized: "Boat")
    default: rawValue
    }
  }
}

extension Countdown {
  private static let clock = Date.VerbatimFormatStyle(
    format:
      "\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits)",
    timeZone: .current, calendar: .current)

  var text: String {
    switch self {
    case .now: String(localized: "now")
    case .minutes(let minutes): String(localized: "\(minutes) min")
    case .clock(let date): date.formatted(Self.clock)
    }
  }
}

enum Language {
  static var norwegian: Bool {
    Bundle.main.preferredLocalizations.first == "nb"
  }
}

struct LineBadge: View {
  let line: Line
  var height: CGFloat = 26
  var fontSize: CGFloat = 15

  var body: some View {
    Text(line.code)
      .font(.system(size: fontSize, weight: .bold))
      .monospacedDigit()
      .lineLimit(1)
      .fixedSize()
      .foregroundStyle(Palette.ink(of: line))
      .padding(.horizontal, 6)
      .frame(minWidth: 34, minHeight: height, maxHeight: height)
      .background(Palette.fill(of: line), in: .rect(cornerRadius: 6))
      .accessibilityLabel(Text("Line \(line.code)"))
  }
}

struct PlatformChip: View {
  let code: String
  var tint = Palette.lavender

  var body: some View {
    Text(code)
      .font(.system(size: 12))
      .foregroundStyle(tint)
      .lineLimit(1)
      .fixedSize()
      .padding(.horizontal, 4)
      .frame(minWidth: 20, minHeight: 18)
      .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(tint.opacity(0.45)))
      .accessibilityLabel(Text("Platform \(code)"))
  }
}
