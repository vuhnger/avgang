import AppKit
import AvgangCore
import CoreLocation

enum LocationAccess: Equatable {
  case undecided
  case allowed
  case denied

  static var current: LocationAccess {
    switch CLLocationManager().authorizationStatus {
    case .authorized, .authorizedAlways: .allowed
    case .denied, .restricted: .denied
    default: .undecided
    }
  }

  static func openSystemSettings() {
    guard
      let url = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")
    else { return }
    NSWorkspace.shared.open(url)
  }
}

@MainActor
final class LocationWatcher {
  static let moveThreshold = 100.0

  private let manager = CLLocationManager()
  private var task: Task<Void, Never>?
  private var last: Coordinate?

  var onMove: (Coordinate) -> Void = { _ in }
  var onAccess: (LocationAccess) -> Void = { _ in }

  func start() {
    guard task == nil else { return }
    if manager.authorizationStatus == .notDetermined {
      manager.requestWhenInUseAuthorization()
    }
    task = Task { [weak self] in
      do {
        for try await update in CLLocationUpdate.liveUpdates() {
          guard let self else { return }
          self.receive(update)
        }
      } catch {
        self?.task = nil
        self?.last = nil
        self?.onAccess(.denied)
      }
    }
  }

  func stop() {
    task?.cancel()
    task = nil
    last = nil
  }

  private func receive(_ update: CLLocationUpdate) {
    if update.authorizationDenied || update.authorizationDeniedGlobally
      || update.authorizationRestricted
    {
      last = nil
      onAccess(.denied)
      return
    }
    guard let location = update.location else { return }
    onAccess(.allowed)
    let here = Coordinate(
      latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
    if let last, last.distance(to: here) < Self.moveThreshold { return }
    last = here
    onMove(here)
  }
}
