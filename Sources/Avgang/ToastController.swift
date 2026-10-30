import AppKit
import AvgangCore
import Observation
import SwiftUI

final class ToastPanel: NSPanel {
  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}

final class ToastHostingView: NSHostingView<ToastStackView> {
  var pointerChanged: (Bool) -> Void = { _ in }

  required init(rootView: ToastStackView) {
    super.init(rootView: rootView)
    addTrackingArea(
      NSTrackingArea(
        rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
        owner: self, userInfo: nil))
  }

  @MainActor @preconcurrency required init?(coder: NSCoder) { nil }

  override func mouseEntered(with event: NSEvent) { pointerChanged(true) }

  override func mouseExited(with event: NSEvent) { pointerChanged(false) }
}

struct ToastItem: Identifiable {
  let id = UUID()
  let alert: TravelAlert
  var fading = false

  var sticky: Bool {
    if case .leave = alert { return true }
    return false
  }
}

@MainActor
@Observable
final class ToastModel {
  var items: [ToastItem] = []
}

@MainActor
final class ToastController {
  private static let limit = 3
  private static let lifetime: Duration = .seconds(6)
  private static let fade: Duration = .milliseconds(250)

  private let model = ToastModel()
  private let anchor: () -> NSRect?
  private let open: () -> Void
  private let panel: ToastPanel
  private let hosting: ToastHostingView
  private var timers: [UUID: Task<Void, Never>] = [:]
  private var size = CGSize.zero
  private var hovering = false

  init(anchor: @escaping () -> NSRect?, open: @escaping () -> Void) {
    self.anchor = anchor
    self.open = open
    hosting = ToastHostingView(
      rootView: ToastStackView(model: model, tap: { _ in }, close: { _ in }, resized: { _ in }))
    hosting.sizingOptions = []
    panel = ToastPanel(
      contentRect: .zero, styleMask: [.nonactivatingPanel, .borderless], backing: .buffered,
      defer: false)
    panel.contentView = hosting
    panel.isFloatingPanel = true
    panel.level = .popUpMenu
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.hidesOnDeactivate = false
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.appearance = NSAppearance(named: .darkAqua)
    hosting.rootView = ToastStackView(
      model: model,
      tap: { [weak self] id in self?.tap(id) },
      close: { [weak self] id in self?.remove(id) },
      resized: { [weak self] size in
        self?.size = size
        self?.layout()
      })
    hosting.pointerChanged = { [weak self] inside in self?.pointerChanged(inside) }
    track({ [model] in model.items.map(\.id) }, apply: { [weak self] _ in self?.layout() })
  }

  func show(_ alert: TravelAlert) {
    let item = ToastItem(alert: alert)
    var kept = [item] + model.items
    while kept.count > Self.limit {
      kept.remove(at: kept.lastIndex { !$0.sticky } ?? kept.count - 1)
    }
    for id in timers.keys where !kept.contains(where: { $0.id == id }) { cancelTimer(id) }
    model.items = kept
    if !hovering { startTimer(item) }
  }

  func clear() {
    hovering = false
    for id in Array(timers.keys) { cancelTimer(id) }
    model.items = []
  }

  private func startTimer(_ item: ToastItem) {
    guard !item.sticky else { return }
    timers[item.id]?.cancel()
    timers[item.id] = Task { [weak self] in
      try? await Task.sleep(for: Self.lifetime)
      guard !Task.isCancelled else { return }
      self?.fadeOut(item.id)
    }
  }

  private func cancelTimer(_ id: UUID) {
    timers[id]?.cancel()
    timers[id] = nil
  }

  private func fadeOut(_ id: UUID) {
    timers[id] = nil
    guard let index = model.items.firstIndex(where: { $0.id == id }) else { return }
    withAnimation(.easeOut(duration: 0.25)) { model.items[index].fading = true }
    Task { [weak self] in
      try? await Task.sleep(for: Self.fade)
      self?.remove(id)
    }
  }

  private func remove(_ id: UUID) {
    cancelTimer(id)
    model.items.removeAll { $0.id == id }
  }

  private func pointerChanged(_ inside: Bool) {
    hovering = inside
    for item in model.items where !item.fading {
      if inside { cancelTimer(item.id) } else { startTimer(item) }
    }
  }

  private func tap(_ id: UUID) {
    remove(id)
    open()
  }

  private func layout() {
    guard !model.items.isEmpty else {
      hovering = false
      panel.orderOut(nil)
      return
    }
    guard size.width > 0, size.height > 0 else { return }
    let screens = NSScreen.screens.map {
      PanelPlacement.Screen(frame: $0.frame, visibleFrame: $0.visibleFrame)
    }
    let flush = PanelPlacement.Insets(leading: 0, trailing: 0, top: 0)
    let origin: CGPoint
    if let icon = anchor(),
      let placed = PanelPlacement.origin(
        icon: icon, screens: screens, insets: flush, panelSize: size)
    {
      origin = placed
    } else {
      let screen = NSScreen.main?.visibleFrame ?? .zero
      origin = CGPoint(
        x: screen.maxX - size.width - PanelPlacement.margin,
        y: screen.maxY - PanelPlacement.gap - size.height)
    }
    panel.setFrame(NSRect(origin: origin, size: size), display: true)
    panel.orderFrontRegardless()
  }
}

struct ToastStackView: View {
  let model: ToastModel
  let tap: (UUID) -> Void
  let close: (UUID) -> Void
  let resized: (CGSize) -> Void

  var body: some View {
    VStack(spacing: 8) {
      ForEach(model.items) { item in
        ToastCard(alert: item.alert, close: { close(item.id) })
          .opacity(item.fading ? 0 : 1)
          .contentShape(.rect)
          .onTapGesture { tap(item.id) }
      }
    }
    .fixedSize()
    .onGeometryChange(for: CGSize.self, of: \.size, action: resized)
    .preferredColorScheme(.dark)
  }
}

struct ToastCard: View {
  let alert: TravelAlert
  let close: () -> Void

  var body: some View {
    HStack(spacing: 10) {
      content
      Button(action: close) {
        Image(systemName: "xmark")
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(Palette.lavender)
          .frame(width: 20, height: 20)
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .help("Close")
      .accessibilityLabel("Close")
    }
    .padding(.horizontal, BoardMetrics.sidePadding)
    .padding(.vertical, 12)
    .frame(width: BoardMetrics.width)
    .foregroundStyle(.white)
    .background(Palette.navy, in: .rect(cornerRadius: BoardMetrics.radius))
  }

  private var content: some View {
    HStack(spacing: 10) {
      leading.frame(width: 38, alignment: .leading)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(titleColor)
          .lineLimit(1)
        Text(detail)
          .font(.system(size: 13))
          .foregroundStyle(Palette.lavender)
          .lineLimit(3)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      if let departure {
        Text(Countdown.clock(departure.expected).text)
          .font(.system(size: 17, weight: .semibold))
          .monospacedDigit()
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isButton)
  }

  @ViewBuilder private var leading: some View {
    switch alert {
    case .leave(let departure, _), .cancelled(let departure, _):
      LineBadge(line: departure.line)
    case .disruption:
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 16))
        .foregroundStyle(Palette.canary)
    }
  }

  private var departure: Departure? {
    switch alert {
    case .leave(let departure, _), .cancelled(let departure, _): departure
    case .disruption: nil
    }
  }

  private var title: String {
    switch alert {
    case .leave: String(localized: "Time to leave")
    case .cancelled: String(localized: "Cancelled")
    case .disruption(_, let stop): stop
    }
  }

  private var titleColor: Color {
    if case .cancelled = alert { return Palette.coral }
    return .white
  }

  private var detail: String {
    switch alert {
    case .leave(let departure, let stop), .cancelled(let departure, let stop):
      String(localized: "\(departure.destination) from \(stop)")
    case .disruption(let notice, _):
      notice.text(norwegian: Language.norwegian) ?? ""
    }
  }
}
