import AvgangCore
import SwiftUI

struct NumberField: View {
  let title: LocalizedStringKey
  @Binding var value: Int
  let range: ClosedRange<Int>
  var unit: LocalizedStringKey?
  @State private var text = ""
  @FocusState private var focused: Bool

  var body: some View {
    LabeledContent(title) {
      HStack(spacing: 6) {
        TextField(title, text: $text)
          .labelsHidden()
          .textFieldStyle(.roundedBorder)
          .multilineTextAlignment(.trailing)
          .monospacedDigit()
          .frame(width: 48)
          .focused($focused)
          .onSubmit(commit)
        if let unit { Text(unit).foregroundStyle(.secondary) }
      }
    }
    .onAppear { text = "\(value)" }
    .onChange(of: text) {
      if let number = range.number(typed: text), range.contains(number), number != value {
        value = number
      }
    }
    .onChange(of: value) { if !focused { text = "\(value)" } }
    .onChange(of: focused) { if !focused { commit() } }
  }

  private func commit() {
    let number = range.clamped(typed: text, otherwise: value)
    if number != value { value = number }
    text = "\(number)"
  }
}
