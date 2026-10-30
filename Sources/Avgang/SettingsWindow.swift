import AppKit
import AvgangCore
import SwiftUI

enum SettingsMetrics {
  static let width: CGFloat = 640
  static let stopsHeight: CGFloat = 460
  static let listWidth: CGFloat = 250
}

@MainActor
final class SettingsWindow: NSObject, NSWindowDelegate {
  private let monitor: Monitor
  private let launchAtLogin = LaunchAtLogin()
  private let recorder: ShortcutRecorder
  private var window: NSWindow?

  init(
    monitor: Monitor, shortcut: Shortcut, suspendShortcut: @escaping () -> Void,
    resumeShortcut: @escaping () -> Void, applyShortcut: @escaping (Shortcut) -> Bool
  ) {
    self.monitor = monitor
    recorder = ShortcutRecorder(
      shortcut: shortcut, suspend: suspendShortcut, resume: resumeShortcut, apply: applyShortcut)
    super.init()
  }

  func windowDidResignKey(_ notification: Notification) {
    recorder.cancel()
  }

  func windowWillClose(_ notification: Notification) {
    recorder.cancel()
  }

  func windowDidBecomeKey(_ notification: Notification) {
    launchAtLogin.refresh()
  }

  func show() {
    let window = self.window ?? makeWindow()
    self.window = window
    NSApp.activate()
    window.makeKeyAndOrderFront(nil)
  }

  private func makeWindow() -> NSWindow {
    let tabs = NSTabViewController()
    tabs.tabStyle = .toolbar
    tabs.addTabViewItem(
      tab(StopsPane(monitor: monitor), label: String(localized: "Stops"), symbol: "star"))
    tabs.addTabViewItem(
      tab(
        NearbyPane(monitor: monitor), label: String(localized: "Nearby"), symbol: "location"))
    tabs.addTabViewItem(
      tab(
        MenuBarPane(monitor: monitor), label: String(localized: "Menu Bar"),
        symbol: "menubar.rectangle"))
    tabs.addTabViewItem(
      tab(
        GeneralPane(monitor: monitor, launchAtLogin: launchAtLogin, recorder: recorder),
        label: String(localized: "General"), symbol: "gearshape"))
    let window = NSWindow(contentViewController: tabs)
    window.styleMask = [.titled, .closable, .miniaturizable]
    window.toolbarStyle = .preference
    window.isReleasedWhenClosed = false
    window.delegate = self
    window.center()
    return window
  }

  private func tab(_ view: some View, label: String, symbol: String) -> NSTabViewItem {
    let controller = NSHostingController(rootView: view)
    controller.sizingOptions = .preferredContentSize
    controller.title = label
    let item = NSTabViewItem(viewController: controller)
    item.label = label
    item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
    return item
  }
}
