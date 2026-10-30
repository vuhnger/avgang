import AppKit
import AvgangCore
import Observation

@MainActor
@Observable
final class Monitor {
  static let tick: Duration = .seconds(5)
  static let settleDelay: Duration = .milliseconds(500)
  static let longestSleep: TimeInterval = 300

  var settings: Settings {
    didSet {
      guard settings != oldValue else { return }
      settings.save(to: .standard)
      settingsChanged(from: oldValue)
    }
  }
  private(set) var departures: [String: [Departure]] = [:]
  private(set) var nearbyStops: [NearbyStop] = []
  private(set) var location: Coordinate?
  private(set) var access = LocationAccess.current
  private(set) var now = Date()
  private(set) var unreachable = false

  @ObservationIgnored let client = EnturClient()
  @ObservationIgnored private let watcher = LocationWatcher()
  @ObservationIgnored private var lastError: EnturError?
  @ObservationIgnored private var failures = 0
  @ObservationIgnored private var jitter = 0.0
  @ObservationIgnored private var finishedAt = Date.distantPast
  @ObservationIgnored private var panelVisible = false
  @ObservationIgnored private var forced = false
  @ObservationIgnored private var woke = false
  @ObservationIgnored private var nearbyStale = true
  @ObservationIgnored private var loop: Task<Void, Never>?
  @ObservationIgnored private var sleeper: Task<Void, Never>?
  @ObservationIgnored private var ticker: Task<Void, Never>?
  @ObservationIgnored private var settle: Task<Void, Never>?
  @ObservationIgnored private var wakeObserver: (any NSObjectProtocol)?

  init(settings: Settings = .load(from: .standard)) {
    self.settings = settings
  }

  var sections: [BoardSection] {
    Board.sections(
      settings: settings, departures: departures, nearby: nearbyStops, location: location, now: now)
  }

  var label: MenuBarLabel {
    MenuBarLabel(
      style: settings.label, followed: Board.followed(sections, settings: settings), now: now,
      clockAfter: settings.clockAfter)
  }

  func start() {
    guard loop == nil else { return }
    wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        self?.woke = true
        self?.nudge()
      }
    }
    watcher.onMove = { [weak self] here in
      self?.location = here
      self?.nearbyStale = true
      self?.retry()
    }
    watcher.onAccess = { [weak self] access in
      self?.access = access
      if access == .denied {
        self?.location = nil
        self?.nearbyStops = []
      }
    }
    if settings.nearby.enabled { watcher.start() }
    ticker = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: Self.tick)
        self?.now = Date()
      }
    }
    loop = Task { await run() }
  }

  func retry() {
    forced = true
    nudge()
  }

  func panelVisibilityChanged(_ visible: Bool) {
    panelVisible = visible
    guard visible else { return }
    now = Date()
    if Date().timeIntervalSince(finishedAt) > 1 { retry() }
  }

  private func settingsChanged(from old: Settings) {
    if settings.nearby.enabled != old.nearby.enabled {
      if settings.nearby.enabled {
        watcher.start()
      } else {
        watcher.stop()
        location = nil
        nearbyStops = []
      }
    }
    if settings.nearby.radius != old.nearby.radius { nearbyStale = true }
    settle?.cancel()
    settle = Task { [weak self] in
      try? await Task.sleep(for: Self.settleDelay)
      guard !Task.isCancelled else { return }
      self?.retry()
    }
  }

  private func nudge() {
    sleeper?.cancel()
  }

  private var active: Bool {
    panelVisible || settings.label != .icon
  }

  private var remaining: TimeInterval {
    let delay = PollPolicy.delay(
      after: lastError, failures: failures, active: active, jitter: jitter)
    return finishedAt.addingTimeInterval(delay).timeIntervalSinceNow
  }

  private var due: Bool {
    remaining <= 0 || ((forced || woke) && PollPolicy.allowsForcedPoll(after: lastError))
  }

  private func run() async {
    while !Task.isCancelled {
      if woke { await NetworkGate.waitUntilSatisfied(timeout: .seconds(2)) }
      let poll = due
      woke = false
      forced = false
      if poll { await refresh() }
      let wait = due ? 0.05 : min(max(remaining, 0.05), Self.longestSleep)
      let sleep = Task<Void, Never> { _ = try? await Task.sleep(for: .seconds(wait)) }
      sleeper = sleep
      await sleep.value
    }
  }

  private func refresh() async {
    do {
      if nearbyStale, settings.nearby.enabled, let location,
        let stops = try? await client.nearby(around: location, within: settings.nearby.radius)
      {
        nearbyStops = stops
        nearbyStale = false
      }
      let ids = Board.fetchIDs(settings: settings, nearby: nearbyStops, location: location)
      departures = try await client.departures(stopIDs: ids)
      lastError = nil
      failures = 0
    } catch {
      guard !Task.isCancelled else { return }
      lastError = error as? EnturError ?? .transport
      failures += 1
    }
    unreachable = lastError != nil
    finishedAt = Date()
    jitter = Double.random(in: 0...1)
    now = Date()
  }
}
