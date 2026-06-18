import SwiftUI
import UniformTypeIdentifiers
import YoooooSkillManagerCore

struct AddToolSheet: View {
  @Bindable var store: SkillManagerStore
  @Environment(\.dismiss) private var dismiss
  @State private var name = ""
  @State private var skillsDirectory = ""
  @State private var showingDirectoryImporter = false

  private var canAdd: Bool {
    !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !skillsDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Add App")
        .font(.title2)
        .fontWeight(.semibold)

      SettingsFormStack {
        SettingsFormRow(title: "Name") {
          SettingsTextField(prompt: "App name", text: $name)
        }

        SettingsFormRow(title: "Skills Directory") {
          SettingsPathPickerField(prompt: "Path", path: $skillsDirectory) {
            showingDirectoryImporter = true
          }
        }
      }

      SettingsFooterActions {
        Button("Cancel") {
          dismiss()
        }
        Button("Add") {
          store.addCustomTool(name: name, skillsDirectory: skillsDirectory)
          dismiss()
        }
        .keyboardShortcut(.defaultAction)
        .disabled(!canAdd)
      }
    }
    .padding(24)
    .frame(width: 620)
    .fileImporter(
      isPresented: $showingDirectoryImporter,
      allowedContentTypes: [.folder],
      allowsMultipleSelection: false
    ) { result in
      switch result {
      case let .success(urls):
        if let url = urls.first {
          skillsDirectory = url.path
        }
      case let .failure(error):
        store.report(error.localizedDescription)
      }
    }
  }
}
