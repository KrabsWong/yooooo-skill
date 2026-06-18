import SwiftUI
import UniformTypeIdentifiers
import YoooooSkillManagerCore

struct AddProjectSheet: View {
  @Bindable var store: SkillManagerStore
  @Environment(\.dismiss) private var dismiss
  @State private var name = ""
  @State private var rootPath = ""
  @State private var showingDirectoryImporter = false

  private var canAdd: Bool {
    !rootPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Add Project")
        .font(.title2)
        .fontWeight(.semibold)

      SettingsFormStack {
        SettingsFormRow(title: "Name") {
          SettingsTextField(prompt: "Optional", text: $name)
        }

        SettingsFormRow(title: "Project Directory") {
          SettingsPathPickerField(prompt: "Path", path: $rootPath) {
            showingDirectoryImporter = true
          }
        }

        SettingsFormRow(title: "Skills Directory") {
          SettingsReadOnlyValue(
            projectSkillsDirectory,
            isPlaceholder: rootPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          )
        }
      }

      SettingsFooterActions {
        Button("Cancel") {
          dismiss()
        }
        Button("Add") {
          store.addProject(name: name, rootPath: rootPath)
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
          rootPath = url.path
          if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            name = url.lastPathComponent
          }
        }
      case let .failure(error):
        store.report(error.localizedDescription)
      }
    }
  }

  private var projectSkillsDirectory: String {
    guard !rootPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return "Choose a project directory"
    }

    return URL(fileURLWithPath: PathHelpers.expandHome(rootPath), isDirectory: true)
      .appendingPathComponent(".agents", isDirectory: true)
      .appendingPathComponent("skills", isDirectory: true)
      .standardizedFileURL
      .path
  }
}
