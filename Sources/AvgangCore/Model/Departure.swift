import Foundation

public struct Line: Hashable, Sendable, Identifiable {
  public let id: String
  public let code: String
  public let mode: TransportMode
  public let colour: String?
  public let textColour: String?

  public init(
    id: String, code: String, mode: TransportMode, colour: String? = nil,
    textColour: String? = nil
  ) {
    self.id = id
    self.code = code
    self.mode = mode
    self.colour = colour
    self.textColour = textColour
  }
}

public typealias Notice = [String: String]

public struct Departure: Equatable, Sendable, Identifiable {
  public let id: String
  public let line: Line
  public let destination: String
  public let quayID: String
  public let platform: String?
  public let aimed: Date
  public let expected: Date
  public let realtime: Bool
  public let cancelled: Bool
  public let notices: [Notice]

  public init(
    id: String, line: Line, destination: String, quayID: String, platform: String?,
    aimed: Date, expected: Date, realtime: Bool, cancelled: Bool, notices: [Notice] = []
  ) {
    self.id = id
    self.line = line
    self.destination = destination
    self.quayID = quayID
    self.platform = platform
    self.aimed = aimed
    self.expected = expected
    self.realtime = realtime
    self.cancelled = cancelled
    self.notices = notices
  }

  public var delayMinutes: Int {
    max(0, Int(expected.timeIntervalSince(aimed) / 60))
  }

  public func leaves(walkMinutes: Int) -> Date {
    expected.addingTimeInterval(-Double(walkMinutes) * 60)
  }

  public func reachable(walkMinutes: Int, now: Date) -> Bool {
    leaves(walkMinutes: walkMinutes) >= now
  }
}

extension Notice {
  private static let norwegian = ["no", "nob", "nb", "nn", "nno"]

  public func text(norwegian: Bool) -> String? {
    let wanted = norwegian ? Self.norwegian : ["en", "eng"]
    return wanted.lazy.compactMap { self[$0] }.first ?? values.sorted().first
  }
}
