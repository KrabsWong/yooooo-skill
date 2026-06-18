import SwiftUI

private let settingsLabelWidth: CGFloat = 148

struct SettingsFormStack<Content: View>: View {
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      content
    }
  }
}

struct SettingsFormRow<Content: View>: View {
  var title: String
  @ViewBuilder var content: Content

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 12) {
      Text(title)
        .font(.body)
        .foregroundStyle(.primary)
        .frame(width: settingsLabelWidth, alignment: .trailing)

      content
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

struct SettingsTextField: View {
  var prompt: String
  @Binding var text: String

  var body: some View {
    TextField(prompt, text: $text)
      .textFieldStyle(.roundedBorder)
      .controlSize(.large)
  }
}

struct SettingsPathPickerField: View {
  var prompt: String
  @Binding var path: String
  var action: () -> Void

  var body: some View {
    HStack(spacing: 8) {
      SettingsTextField(prompt: prompt, text: $path)

      Button(action: action) {
        Image(systemName: "folder")
      }
      .buttonStyle(.borderless)
      .controlSize(.large)
      .help(prompt)
    }
  }
}

struct SettingsReadOnlyValue: View {
  var value: String
  var isPlaceholder: Bool

  init(_ value: String, isPlaceholder: Bool = false) {
    self.value = value
    self.isPlaceholder = isPlaceholder
  }

  var body: some View {
    Text(value)
      .font(.body)
      .foregroundStyle(isPlaceholder ? .tertiary : .secondary)
      .lineLimit(1)
      .truncationMode(.middle)
      .textSelection(.enabled)
      .frame(minHeight: 28, alignment: .center)
  }
}

struct SettingsFooterActions<Content: View>: View {
  @ViewBuilder var content: Content

  var body: some View {
    HStack(spacing: 10) {
      Spacer()
      content
    }
  }
}
