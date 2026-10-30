import AvgangCore
import Observation
import SwiftUI

@MainActor
@Observable
final class PanelSize {
  var height: CGFloat = 120
}

enum BoardMetrics {
  static let width: CGFloat = 344
  static let radius: CGFloat = 16
  static let row: CGFloat = 40
  static let rule: CGFloat = 1
  static let band: CGFloat = 6
  static let sidePadding: CGFloat = 14
}

struct BoardView: View {
  let monitor: Monitor
  let size: PanelSize
  let openSettings: () -> Void

  var body: some View {
    let sections = monitor.sections
    ScrollView(.vertical) {
      VStack(spacing: 0) {
        if sections.isEmpty {
          Text(emptyText)
            .font(.system(size: 13))
            .foregroundStyle(Palette.lavender)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, BoardMetrics.sidePadding)
            .padding(.vertical, 16)
        }
        ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
          if index > 0 { Palette.band.frame(height: BoardMetrics.band) }
          StopSection(
            section: section, now: monitor.now, clockAfter: monitor.settings.clockAfter,
            reminders: monitor.reminders,
            toggleReminder: { monitor.toggleReminder(for: $0, in: section) })
        }
        footer
      }
      .onGeometryChange(for: CGFloat.self) {
        $0.size.height
      } action: {
        size.height = $0
      }
    }
    .scrollIndicators(.hidden)
    .scrollBounceBehavior(.basedOnSize)
    .focusEffectDisabled()
    .foregroundStyle(.white)
    .frame(width: BoardMetrics.width)
    .background(Palette.navy)
    .clipShape(.rect(cornerRadius: BoardMetrics.radius))
    .preferredColorScheme(.dark)
  }

  private var emptyText: LocalizedStringKey {
    if let place = monitor.place, !monitor.settings.favorites.isEmpty {
      return "No stops are checked for \(place.name). Check them under Places in Settings."
    }
    if !monitor.settings.nearby.enabled { return "Add a stop in Settings to see departures here." }
    if monitor.access == .denied {
      return "Location is off for Avgang. Turn it on in System Settings to see stops near you."
    }
    if monitor.location == nil { return "Looking for departures near you." }
    return "No departures to catch right now."
  }

  private var footer: some View {
    HStack {
      if let place = monitor.place {
        Text("At \(place.name)")
          .font(.system(size: 12))
          .foregroundStyle(Palette.lavender)
          .lineLimit(1)
      }
      if monitor.unreachable {
        Text("Could not reach Entur. Showing the last board.")
          .font(.system(size: 12))
          .foregroundStyle(Palette.lavender)
          .lineLimit(2)
      }
      Spacer(minLength: 8)
      Button(action: openSettings) {
        Image(systemName: "gearshape")
          .font(.system(size: 14))
          .frame(width: 28, height: 24)
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(Text("Settings"))
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 6)
    .overlay(alignment: .top) { Palette.rule.frame(height: BoardMetrics.rule) }
  }
}

private struct StopSection: View {
  let section: BoardSection
  let now: Date
  let clockAfter: Int
  let reminders: [String: Reminder]
  let toggleReminder: (Departure) -> Void

  var body: some View {
    VStack(spacing: 0) {
      header
      if let notice {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 12))
          Text(notice).font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
          Spacer(minLength: 0)
        }
        .foregroundStyle(Palette.canary)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .overlay(alignment: .top) { Palette.rule.frame(height: BoardMetrics.rule) }
      }
      if section.departures.isEmpty {
        Text("No departures to catch right now.")
          .font(.system(size: 13))
          .foregroundStyle(Palette.lavender)
          .frame(maxWidth: .infinity, minHeight: BoardMetrics.row, alignment: .leading)
          .overlay(alignment: .top) { Palette.rule.frame(height: BoardMetrics.rule) }
      }
      ForEach(section.departures) { departure in
        DepartureRow(
          departure: departure, now: now, clockAfter: clockAfter,
          walkMinutes: section.walkMinutes, armed: reminders[departure.id] != nil,
          toggle: { toggleReminder(departure) })
      }
    }
    .padding(.horizontal, BoardMetrics.sidePadding)
    .padding(.top, 12)
    .padding(.bottom, 4)
  }

  private var header: some View {
    HStack(spacing: 8) {
      Image(
        systemName: section.origin == .nearby
          ? "location.fill" : (section.modes.first ?? .unknown).symbol
      )
      .font(.system(size: 14))
      .foregroundStyle(Palette.lavender)
      .frame(width: 18)
      Text(section.name)
        .font(.system(size: 16, weight: .semibold))
        .lineLimit(1)
        .truncationMode(.tail)
      Spacer(minLength: 8)
      meta
        .font(.system(size: 13))
        .monospacedDigit()
        .foregroundStyle(Palette.lavender)
    }
    .frame(minHeight: 26)
    .padding(.bottom, 4)
  }

  @ViewBuilder private var meta: some View {
    switch section.origin {
    case .favorite:
      HStack(spacing: 4) {
        Image(systemName: "figure.walk")
        Text("\(section.walkMinutes) min")
      }
      .accessibilityElement(children: .combine)
    case .nearby:
      Text("\(section.distance ?? 0) m")
    }
  }

  private var notice: String? {
    section.departures.lazy.flatMap(\.notices)
      .compactMap { $0.text(norwegian: Language.norwegian) }.first
  }
}

private struct DepartureRow: View {
  let departure: Departure
  let now: Date
  let clockAfter: Int
  let walkMinutes: Int
  let armed: Bool
  let toggle: () -> Void
  @State private var hovering = false

  var body: some View {
    let armable = Reminders.armable(departure, walkMinutes: walkMinutes, now: now)
    HStack(spacing: 10) {
      LineBadge(line: departure.line)
        .frame(width: 38, alignment: .leading)
        .opacity(departure.cancelled ? 0.55 : 1)
      Text(departure.destination)
        .font(.system(size: 15))
        .lineLimit(1)
        .truncationMode(.tail)
        .strikethrough(departure.cancelled)
        .opacity(departure.cancelled ? 0.55 : 1)
        .frame(maxWidth: .infinity, alignment: .leading)
      if armed || (hovering && armable) {
        Button(action: toggle) {
          Image(systemName: armed ? "bell.fill" : "bell")
            .font(.system(size: 13))
            .foregroundStyle(armed ? Color.white : Palette.lavender)
            .frame(width: 22, height: 24)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(reminderLabel)
        .accessibilityHidden(true)
      }
      if let platform = departure.platform { PlatformChip(code: platform) }
      time.frame(minWidth: 64, alignment: .trailing)
    }
    .frame(height: BoardMetrics.row)
    .contentShape(.rect)
    .onHover { hovering = $0 }
    .overlay(alignment: .top) { Palette.rule.frame(height: BoardMetrics.rule) }
    .accessibilityElement(children: .combine)
    .accessibilityValue(armed ? Text("Reminder set") : Text(verbatim: ""))
    .accessibilityActions {
      if armed || armable { Button(reminderLabel, action: toggle) }
    }
  }

  private var reminderLabel: LocalizedStringKey {
    armed ? "Cancel reminder" : "Remind me when to leave"
  }

  @ViewBuilder private var time: some View {
    if departure.cancelled {
      Text("Cancelled")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(Palette.coral)
    } else {
      let countdown = Countdown(until: departure.expected, now: now, clockAfter: clockAfter)
      let shown = countdown.text
      let exact = departure.realtime || countdown == .now
      HStack(alignment: .firstTextBaseline, spacing: 4) {
        if departure.delayMinutes > 0 {
          Text("+\(departure.delayMinutes)")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Palette.canary)
        }
        Text(exact ? shown : String(localized: "ca. \(shown)"))
          .font(.system(size: 17, weight: departure.realtime ? .semibold : .medium))
          .foregroundStyle(departure.realtime ? Color.white : Palette.lavender)
      }
      .monospacedDigit()
      .lineLimit(1)
      .fixedSize()
    }
  }
}
