import AppKit
import AvgangCore
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
  private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  private var shown: MenuBarLabel?
  var onClick: () -> Void = {}
  var onMenu: (Bool) -> Void = { _ in }
  var onSettings: () -> Void = {}
  var onCheck: () -> Void = {}
  var onRefresh: () -> Void = {}
  var canCheck: () -> Bool = { false }

  var frame: NSRect? {
    item.button?.window?.frame
  }

  override init() {
    super.init()
    item.isVisible = true
    item.button?.target = self
    item.button?.action = #selector(clicked)
    item.button?.sendAction(on: [.leftMouseDown, .rightMouseDown])
  }

  func update(_ label: MenuBarLabel) {
    guard label != shown else { return }
    shown = label
    let renderer = ImageRenderer(content: MenuBarLabelView(label: label))
    renderer.scale = item.button?.window?.backingScaleFactor ?? 2
    let image = renderer.nsImage
    image?.isTemplate = true
    item.button?.image = image
    item.button?.setAccessibilityLabel(label.spoken)
  }

  @objc private func clicked() {
    guard let event = NSApp.currentEvent else { return onClick() }
    if event.type == .rightMouseDown || event.modifierFlags.contains(.control) {
      showMenu()
    } else {
      onClick()
    }
  }

  private func showMenu() {
    let menu = NSMenu()
    menu.autoenablesItems = false
    let settings = NSMenuItem(
      title: String(localized: "Settings…"), action: #selector(openSettings), keyEquivalent: ",")
    let check = NSMenuItem(
      title: String(localized: "Check for updates…"), action: #selector(checkForUpdates),
      keyEquivalent: "")
    let refresh = NSMenuItem(
      title: String(localized: "Refresh now"), action: #selector(refreshNow), keyEquivalent: "")
    for entry in [settings, check, refresh] { entry.target = self }
    check.isEnabled = canCheck()
    menu.items = [
      settings, check, refresh, .separator(),
      NSMenuItem(
        title: String(localized: "Quit Avgang"), action: #selector(NSApplication.terminate(_:)),
        keyEquivalent: "q"),
    ]
    onMenu(true)
    item.menu = menu
    item.button?.performClick(nil)
    item.menu = nil
    onMenu(false)
  }

  @objc private func openSettings() { onSettings() }
  @objc private func checkForUpdates() { onCheck() }
  @objc private func refreshNow() { onRefresh() }
}

struct MenuBarLabelView: View {
  let label: MenuBarLabel
  var ink = Color.black

  var body: some View {
    HStack(spacing: 4) {
      switch label {
      case .icon:
        Image(systemName: "tram.fill").font(.system(size: 14))
      case .next(let line, let countdown):
        Text(line)
          .font(.system(size: 11, weight: .bold))
          .padding(.horizontal, 4)
          .frame(minWidth: 18, minHeight: 16)
          .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(lineWidth: 1.5))
        Text(countdown.text).font(.system(size: 13, weight: .medium))
      case .leave(let countdown):
        Image(systemName: "figure.walk").font(.system(size: 13))
        Text(countdown.text).font(.system(size: 13, weight: .medium))
      }
    }
    .monospacedDigit()
    .lineLimit(1)
    .fixedSize()
    .foregroundStyle(ink)
    .frame(height: 22)
  }
}

extension MenuBarLabel {
  var spoken: String {
    switch self {
    case .icon: String(localized: "Avgang")
    case .next(let line, let countdown): String(localized: "Line \(line), \(countdown.text)")
    case .leave(.now): String(localized: "Leave now")
    case .leave(let countdown): String(localized: "Leave in \(countdown.text)")
    }
  }
}
