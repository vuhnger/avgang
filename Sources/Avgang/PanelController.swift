import AppKit
import AvgangCore
import Carbon.HIToolbox
import Observation
import SwiftUI

final class BoardPanel: NSPanel {
  var onCancel: () -> Void = {}

  override var canBecomeKey: Bool { true }

  override func cancelOperation(_ sender: Any?) { onCancel() }
}

@MainActor
func track<Value>(
  _ read: @escaping @MainActor () -> Value, apply: @escaping @MainActor (Value) -> Void
) {
  let value = withObservationTracking {
    read()
  } onChange: {
    RunLoop.main.perform(inModes: [.common]) {
      MainActor.assumeIsolated { track(read, apply: apply) }
    }
  }
  apply(value)
}

@MainActor
final class PanelController: NSObject {
  private static var shared: PanelController?
  private static let hotKeySignature: OSType = 0x4156_474E

  private let monitor: Monitor
  private let anchor: () -> NSRect?
  private let panel: BoardPanel
  private let size = PanelSize()
  private var machine = PanelMachine()
  private var timer: Task<Void, Never>?
  private var outsideClicks: Any?
  private var pointerMonitors: [Any] = []
  private var hotKey: EventHotKeyRef?
  private(set) var shortcut = Shortcut.load(from: .standard)
  private var menuUp = false
  var openSettings: () -> Void = {}

  init(monitor: Monitor, anchor: @escaping () -> NSRect?) {
    self.monitor = monitor
    self.anchor = anchor
    panel = BoardPanel(
      contentRect: NSRect(x: 0, y: 0, width: BoardMetrics.width, height: 120),
      styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
    super.init()
    let hosting = NSHostingView(
      rootView: BoardView(
        monitor: monitor, size: size,
        openSettings: { [weak self] in
          self?.send(.dismiss)
          self?.openSettings()
        }
      )
      .environment(\.controlActiveState, .key))
    hosting.sizingOptions = []
    panel.contentView = hosting
    panel.isFloatingPanel = true
    panel.level = .popUpMenu
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.hidesOnDeactivate = false
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.appearance = NSAppearance(named: .darkAqua)
    panel.onCancel = { [weak self] in self?.send(.escape) }
    track({ [size] in size.height }, apply: { [weak self] _ in self?.resize() })
    warmUp()
    watchPointer()
    registerHotKey()
  }

  func menuChanged(open: Bool) {
    menuUp = open
    if open { send(.dismiss) }
  }

  func iconClicked() {
    send(.iconClick)
  }

  private func send(_ input: PanelInput) {
    if case .timer = input { samplePointer() }
    for effect in machine.handle(input) {
      switch effect {
      case .show: show()
      case .hide: hide()
      case .cancelTimer: timer?.cancel()
      case .schedule(let scheduled):
        timer?.cancel()
        timer = Task { [weak self] in
          try? await Task.sleep(for: .seconds(scheduled.delay))
          guard !Task.isCancelled else { return }
          self?.send(.timer(scheduled))
        }
      }
    }
  }

  private func warmUp() {
    resize()
    panel.alphaValue = 0
    panel.orderFrontRegardless()
    panel.contentView?.layoutSubtreeIfNeeded()
    panel.displayIfNeeded()
    panel.orderOut(nil)
    panel.alphaValue = 1
  }

  private func show() {
    if !panel.isVisible {
      resize()
      position()
      panel.orderFrontRegardless()
      watchOutsideClicks()
      monitor.panelVisibilityChanged(true)
    }
    panel.makeKey()
  }

  private func hide() {
    timer?.cancel()
    panel.orderOut(nil)
    if let outsideClicks { NSEvent.removeMonitor(outsideClicks) }
    outsideClicks = nil
    monitor.panelVisibilityChanged(false)
  }

  private func screenFrame() -> NSRect {
    (NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main)?
      .visibleFrame ?? .zero
  }

  private func resize() {
    let cap = max(120, screenFrame().height - 16)
    let height = min(size.height.rounded(.up), cap)
    let frame = panel.frame
    guard abs(frame.height - height) > 0.5 else { return }
    panel.setFrame(
      NSRect(x: frame.minX, y: frame.maxY - height, width: BoardMetrics.width, height: height),
      display: panel.isVisible)
    panel.invalidateShadow()
  }

  private func position() {
    let size = panel.frame.size
    let screens = NSScreen.screens.map {
      PanelPlacement.Screen(frame: $0.frame, visibleFrame: $0.visibleFrame)
    }
    if let icon = anchor(),
      let origin = PanelPlacement.origin(
        icon: icon, screens: screens,
        insets: PanelPlacement.Insets(leading: 0, trailing: 0, top: 0),
        panelSize: size)
    {
      panel.setFrameOrigin(origin)
      return
    }
    let screen = NSScreen.main?.visibleFrame ?? screenFrame()
    panel.setFrameOrigin(
      NSPoint(
        x: screen.maxX - size.width - PanelPlacement.margin,
        y: screen.maxY - PanelPlacement.gap - size.height))
  }

  private func watchOutsideClicks() {
    guard outsideClicks == nil else { return }
    outsideClicks = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
      [weak self] _ in
      MainActor.assumeIsolated { self?.send(.outsideClick) }
    }
  }

  private func watchPointer() {
    pointerMonitors = [
      NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
        MainActor.assumeIsolated { self?.samplePointer() }
      },
      NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
        MainActor.assumeIsolated { self?.samplePointer() }
        return event
      },
    ].compactMap { $0 }
  }

  private func samplePointer() {
    guard !menuUp, monitor.settings.openWith == .hover else { return }
    let location = NSEvent.mouseLocation
    let overIcon = anchor().map { Self.contains($0, location) } ?? false
    let overPanel = panel.isVisible && Self.contains(panel.frame, location)
    send(.pointer(overIcon: overIcon, overPanel: overPanel))
  }

  private static func contains(_ rect: NSRect, _ point: NSPoint) -> Bool {
    point.x >= rect.minX && point.x <= rect.maxX && point.y >= rect.minY && point.y <= rect.maxY
  }

  private func registerHotKey() {
    Self.shared = self
    var spec = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    InstallEventHandler(
      GetApplicationEventTarget(),
      { _, _, _ in
        MainActor.assumeIsolated { PanelController.shared?.send(.hotkey) }
        return noErr
      }, 1, &spec, nil, nil)
    _ = registerShortcut(shortcut)
  }

  func suspendHotKey() {
    if let hotKey { UnregisterEventHotKey(hotKey) }
    hotKey = nil
  }

  func resumeHotKey() {
    if hotKey == nil { _ = registerShortcut(shortcut) }
  }

  func setShortcut(_ new: Shortcut) -> Bool {
    suspendHotKey()
    guard registerShortcut(new) else {
      _ = registerShortcut(shortcut)
      return false
    }
    shortcut = new
    new.save(to: .standard)
    return true
  }

  private func registerShortcut(_ value: Shortcut) -> Bool {
    var modifiers = 0
    if value.modifiers.contains(.command) { modifiers |= cmdKey }
    if value.modifiers.contains(.option) { modifiers |= optionKey }
    if value.modifiers.contains(.control) { modifiers |= controlKey }
    if value.modifiers.contains(.shift) { modifiers |= shiftKey }
    return RegisterEventHotKey(
      value.keyCode, UInt32(modifiers), EventHotKeyID(signature: Self.hotKeySignature, id: 1),
      GetApplicationEventTarget(), 0, &hotKey) == noErr
  }
}
