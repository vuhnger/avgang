import AvgangCore
import SwiftUI

struct GeneralPane: View {
  @Bindable var monitor: Monitor
  var launchAtLogin: LaunchAtLogin
  var recorder: ShortcutRecorder

  var body: some View {
    Form {
      Section {
        Picker(selection: $monitor.settings.clockAfter) {
          ForEach(Settings.clockAfterChoices, id: \.self) { minutes in
            Text("\(minutes) min").tag(minutes)
          }
        } label: {
          Text("Show clock time after")
          Text("Departures further away than this show 08:25 instead of a countdown.")
        }
        Toggle("Alert me about disruptions at my stops", isOn: $monitor.settings.alertDisruptions)
        LabeledContent("Keyboard shortcut") {
          Button(
            recorder.recording ? String(localized: "Type a shortcut") : recorder.shortcut.display
          ) {
            recorder.start()
          }
        }
        if let error = recorder.error {
          Text(error).foregroundStyle(.orange)
        }
        Toggle(
          "Launch at login",
          isOn: Binding(get: { launchAtLogin.isOn }, set: { launchAtLogin.set($0) })
        )
        .disabled(launchAtLogin.busy)
        if let error = launchAtLogin.error {
          Text(error).foregroundStyle(.orange)
        }
      }
    }
    .formStyle(.grouped)
    .frame(width: SettingsMetrics.width)
    .fixedSize(horizontal: false, vertical: true)
  }
}
