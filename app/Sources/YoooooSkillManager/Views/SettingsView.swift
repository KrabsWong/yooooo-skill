import SwiftUI
import UniformTypeIdentifiers
import YoooooSkillManagerCore

struct SettingsView: View {
  @Bindable var store: SkillManagerStore
  @State private var showingSourceImporter = false
  @State private var showingAddTool = false
  @State private var showingAddProject = false

  var body: some View {
    TabView {
      SettingsTabPanel {
        SettingsFormStack {
          SettingsFormRow(title: "Skills Directory") {
            HStack(spacing: 8) {
              SettingsReadOnlyValue(PathHelpers.compactHome(store.skillsRootPath))
              Spacer(minLength: 8)
              Button {
                showingSourceImporter = true
              } label: {
                Image(systemName: "folder")
              }
              .buttonStyle(.borderless)
              .controlSize(.large)
              .help("Skills Directory")
            }
          }
        }
      }
      .tabItem {
        Label("Library", systemImage: "shippingbox")
      }

      SettingsTabPanel {
        AppSettingsSection(store: store, showingAddTool: $showingAddTool)
      }
      .tabItem {
        Label("Apps", systemImage: "app.badge")
      }

      SettingsTabPanel {
        VStack(alignment: .leading, spacing: 14) {
          SettingsSectionHeader(title: "Projects")

          if store.projects.isEmpty {
            SettingsEmptyState(text: "No projects registered.")
          } else {
            VStack(spacing: 8) {
              ForEach(store.projects) { project in
                SettingsListRow(
                  title: project.name,
                  detail: project.rootPath,
                  iconSystemName: project.iconSystemName
                ) {
                  store.removeProject(id: project.id)
                }
              }
            }
          }

          Button {
            showingAddProject = true
          } label: {
            Label("Add Project", systemImage: "folder.badge.plus")
          }
        }
      }
      .tabItem {
        Label("Projects", systemImage: "folder.badge.gearshape")
      }
    }
    .frame(width: 720, height: 420)
    .scenePadding()
    .fileImporter(
      isPresented: $showingSourceImporter,
      allowedContentTypes: [.folder],
      allowsMultipleSelection: false
    ) { result in
      switch result {
      case let .success(urls):
        if let url = urls.first {
          store.setSkillsRoot(url.path)
        }
      case let .failure(error):
        store.report(error.localizedDescription)
      }
    }
    .sheet(isPresented: $showingAddTool) {
      AddToolSheet(store: store)
    }
    .sheet(isPresented: $showingAddProject) {
      AddProjectSheet(store: store)
    }
  }
}

private struct SettingsTabPanel<Content: View>: View {
  @ViewBuilder var content: Content

  var body: some View {
    ScrollView {
      content
        .padding(.top, 18)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
  }
}

struct SettingsSectionHeader: View {
  var title: String

  var body: some View {
    Text(title)
      .font(.headline)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct SettingsEmptyState: View {
  var text: String

  var body: some View {
    Text(text)
      .font(.callout)
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 8)
  }
}

struct SettingsListRow: View {
  var title: String
  var detail: String
  var iconSystemName: String
  var iconAssetName: String? = nil
  var badge: String?
  var remove: (() -> Void)?

  var body: some View {
    HStack(spacing: 12) {
      settingsIcon
        .frame(width: 22)

      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 8) {
          Text(title)
            .font(.body)
            .fontWeight(.medium)

          if let badge {
            Text(badge)
              .font(.caption)
              .foregroundStyle(.secondary)
              .padding(.horizontal, 7)
              .padding(.vertical, 3)
              .background(.quaternary, in: Capsule())
          }
        }

        PathText(detail)
      }

      Spacer()

      if let remove {
        Button(role: .destructive, action: remove) {
          Image(systemName: "trash")
        }
        .buttonStyle(.borderless)
        .controlSize(.large)
        .help("Remove")
      } else {
        Image(systemName: "lock")
          .font(.callout)
          .foregroundStyle(.tertiary)
          .frame(width: 28)
          .help("Built-in app")
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
  }

  @ViewBuilder
  private var settingsIcon: some View {
    if let iconAssetName {
      BrandIconImage(assetName: iconAssetName, fallbackSystemName: iconSystemName, size: 22)
        .frame(width: 22, height: 22)
    } else {
      Image(systemName: iconSystemName)
        .foregroundStyle(.secondary)
    }
  }
}
