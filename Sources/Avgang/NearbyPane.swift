import AvgangCore
import SwiftUI

struct NearbyPane: View {
  @Bindable var monitor: Monitor

  var body: some View {
    Form {
      Section {
        Toggle("Show stops near me", isOn: $monitor.settings.nearby.enabled)
        LabeledContent("Location access") { access }
      }
      Section {
        LabeledContent("Within") {
          HStack {
            Slider(value: radius, in: radiusBounds, step: 50).frame(width: 200)
            Text("\(monitor.settings.nearby.radius) m")
              .monospacedDigit()
              .frame(width: 52, alignment: .trailing)
          }
        }
        NumberField(
          title: "Stops shown", value: $monitor.settings.nearby.stops,
          range: NearbySettings.stopsRange)
        NumberField(
          title: "Departures per stop", value: $monitor.settings.nearby.perStop,
          range: NearbySettings.perStopRange)
        LabeledContent("Include") {
          HStack(spacing: 6) {
            ForEach(TransportMode.pickable, id: \.self) { mode in
              Toggle(isOn: included(mode)) {
                Label(mode.title, systemImage: mode.symbol)
              }
              .toggleStyle(.button)
            }
          }
        }
      } footer: {
        Text(
          "Walking time is estimated from the distance. A favorite inside the radius is shown once, as a favorite."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }
      .disabled(!monitor.settings.nearby.enabled)
    }
    .formStyle(.grouped)
    .frame(width: SettingsMetrics.width)
    .fixedSize(horizontal: false, vertical: true)
  }

  private var radiusBounds: ClosedRange<Double> {
    Double(NearbySettings.radiusRange.lowerBound)...Double(NearbySettings.radiusRange.upperBound)
  }

  @ViewBuilder private var access: some View {
    switch monitor.access {
    case .allowed:
      Label("Allowed", systemImage: "checkmark")
    case .denied:
      Button("Open System Settings") { LocationAccess.openSystemSettings() }
    case .undecided:
      Text("Not decided").foregroundStyle(.secondary)
    }
  }

  private var radius: Binding<Double> {
    Binding(
      get: { Double(monitor.settings.nearby.radius) },
      set: { monitor.settings.nearby.radius = Int($0) })
  }

  private func included(_ mode: TransportMode) -> Binding<Bool> {
    Binding(
      get: { monitor.settings.nearby.modes.contains(mode) },
      set: { on in
        if on {
          monitor.settings.nearby.modes.insert(mode)
        } else {
          monitor.settings.nearby.modes.remove(mode)
        }
      })
  }
}
