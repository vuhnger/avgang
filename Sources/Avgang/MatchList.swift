import AvgangCore
import SwiftUI

struct SearchField: View {
  let title: LocalizedStringKey
  @Binding var text: String

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
      TextField(title, text: $text, prompt: Text(title))
        .labelsHidden()
        .textFieldStyle(.plain)
    }
    .padding(.horizontal, 8)
    .frame(height: 28)
    .background(.background, in: .rect(cornerRadius: 7))
    .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(.separator))
  }
}

struct MatchList: View {
  let matches: [StopMatch]
  let failed: Bool
  let add: (StopMatch) -> Void
  var here: (() -> Void)?

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if failed {
        Text("Could not search. Check your connection.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .padding(8)
      }
      if let here {
        row(action: here) {
          Image(systemName: "location")
          Text("Where I am now")
          Spacer(minLength: 4)
        }
      }
      ForEach(matches) { match in
        row(action: { add(match) }) {
          VStack(alignment: .leading, spacing: 1) {
            Text(match.name).lineLimit(1)
            if let locality = match.locality {
              Text(locality).font(.caption).foregroundStyle(.secondary)
            }
          }
          Spacer(minLength: 4)
          ModeIcons(modes: match.modes)
        }
      }
    }
    .background(.background, in: .rect(cornerRadius: 7))
    .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(.separator))
  }

  private func row(action: @escaping () -> Void, @ViewBuilder label: () -> some View)
    -> some View
  {
    Button(action: action) {
      HStack(spacing: 8) {
        label()
        Image(systemName: "plus")
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 5)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
  }
}
