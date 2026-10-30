import AvgangCore
import SwiftUI

struct MenuBarPane: View {
  @Bindable var monitor: Monitor

  var body: some View {
    Form {
      Section {
        Picker("Menu bar label", selection: $monitor.settings.label) {
          ForEach(MenuBarStyle.allCases, id: \.self) { style in
            HStack {
              Text(style.title)
              Spacer()
              MenuBarLabelView(label: style.sample, ink: .primary)
            }
            .tag(style)
          }
        }
        .pickerStyle(.radioGroup)
        .labelsHidden()
      }
      Section {
        Picker(selection: $monitor.settings.follow) {
          Text("First favorite").tag(Follow.firstFavorite)
          Text("Nearest stop").tag(Follow.nearest)
        } label: {
          Text("Follow")
          Text(
            "Nearest stop switches to the closest stop when none of your favorites is within the nearby radius."
          )
        }
        Picker("Open with", selection: $monitor.settings.openWith) {
          Text("Hover").tag(OpenWith.hover)
          Text("Click").tag(OpenWith.click)
        }
      }
    }
    .formStyle(.grouped)
    .frame(width: SettingsMetrics.width)
    .fixedSize(horizontal: false, vertical: true)
  }
}

extension MenuBarStyle {
  fileprivate var title: LocalizedStringKey {
    switch self {
    case .icon: "Icon only"
    case .next: "Next departure"
    case .leave: "Time to leave"
    }
  }

  fileprivate var sample: MenuBarLabel {
    switch self {
    case .icon: .icon
    case .next: .next(line: "3", countdown: .minutes(5))
    case .leave: .leave(.minutes(1))
    }
  }
}
