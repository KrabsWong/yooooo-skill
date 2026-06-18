import SwiftUI
import YoooooSkillManagerCore

private enum SkillInstallationPane: String, CaseIterable, Identifiable {
  case apps
  case projects

  var id: String {
    rawValue
  }

  var title: String {
    switch self {
    case .apps:
      return "Apps"
    case .projects:
      return "Projects"
    }
  }
}

struct SkillDetailView: View {
  @Bindable var store: SkillManagerStore
  var skill: SkillInfo
  @State private var installationPane: SkillInstallationPane = .apps
  @State private var installFilter: SkillInstallFilter = .all

  private var filteredTools: [AgentTool] {
    store.tools.filter { tool in
      installFilter.includes(store.status(skill: skill, tool: tool))
    }
  }

  private var filteredProjects: [ProjectTarget] {
    store.projects.filter { project in
      installFilter.includes(store.status(skill: skill, project: project))
    }
  }

  private var metadataItems: [MetadataItem] {
    [
      MetadataItem(label: "", value: skill.source, tint: .secondary),
      MetadataItem(label: "", value: PathHelpers.compactHome(skill.path), tint: .secondary)
    ]
  }

  private var hasSupplementalMetadata: Bool {
    !skill.author.isEmpty || !skill.license.isEmpty || !skill.compatibility.isEmpty
  }

  private var installationSummary: String {
    let visibleCount = installationPane == .apps ? filteredTools.count : filteredProjects.count
    let totalCount = installationPane == .apps ? store.tools.count : store.projects.count
    let targetName = installationPane == .apps ? "apps" : "projects"

    if installFilter == .all {
      return "\(visibleCount) \(targetName)"
    }

    return "\(visibleCount) of \(totalCount) \(targetName)"
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        VStack(alignment: .leading, spacing: 10) {
          HStack(alignment: .firstTextBaseline) {
            Text(skill.name)
              .font(.largeTitle)
              .fontWeight(.semibold)
            Spacer()
            StatusBadge(
              title: "\(store.installedTools(for: skill).count + store.installedProjects(for: skill).count) targets",
              systemImage: "link",
              tint: .accentColor
            )
          }

          MetadataLine(items: metadataItems)

          if !skill.description.isEmpty {
            Text(skill.description)
              .font(.body)
              .foregroundStyle(.secondary)
              .textSelection(.enabled)
              .lineSpacing(4)
              .lineLimit(nil)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }

        if hasSupplementalMetadata {
          DetailSurface {
            if !skill.author.isEmpty {
              LabeledContent("Author") {
                Text(skill.author)
              }
            }
            if !skill.license.isEmpty {
              LabeledContent("License") {
                Text(skill.license)
              }
            }
            if !skill.compatibility.isEmpty {
              LabeledContent("Compatibility") {
                Text(skill.compatibility)
              }
            }
          }
        }

        VStack(alignment: .leading, spacing: 14) {
          HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
              Text("Installations")
                .font(.headline)
              Text(installationSummary)
                .font(.callout)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("Installation Target", selection: $installationPane) {
              ForEach(SkillInstallationPane.allCases) { pane in
                Text(pane.title).tag(pane)
              }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.regular)
            .frame(width: 180, alignment: .trailing)

            Menu {
              ForEach(SkillInstallFilter.allCases) { filter in
                Button {
                  installFilter = filter
                } label: {
                  if filter == installFilter {
                    Label(filter.title, systemImage: "checkmark")
                  } else {
                    Text(filter.title)
                  }
                }
              }
            } label: {
              Label(installFilter.title, systemImage: "line.3.horizontal.decrease.circle")
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
          }

          switch installationPane {
          case .apps:
            if filteredTools.isEmpty {
              EmptySkillFilterState()
            } else {
              LazyVStack(spacing: 10) {
                ForEach(filteredTools) { tool in
                  ToolInstallRow(store: store, skill: skill, tool: tool)
                }
              }
              .frame(maxWidth: .infinity, alignment: .leading)
            }
          case .projects:
            if store.projects.isEmpty {
              ContentUnavailableView(
                "No Projects",
                systemImage: "folder.badge.gearshape",
                description: Text("Register a project to install this skill locally.")
              )
              .frame(maxWidth: .infinity)
              .padding(.vertical, 40)
            } else if filteredProjects.isEmpty {
              EmptySkillFilterState()
            } else {
              LazyVStack(spacing: 10) {
                ForEach(filteredProjects) { project in
                  ProjectInstallRow(store: store, skill: skill, project: project)
                }
              }
              .frame(maxWidth: .infinity, alignment: .leading)
            }
          }
        }
      }
      .padding(24)
      .frame(maxWidth: 980, alignment: .topLeading)
    }
  }
}

private struct ProjectInstallRow: View {
  @Bindable var store: SkillManagerStore
  var skill: SkillInfo
  var project: ProjectTarget

  private var status: SkillLinkStatus {
    store.status(skill: skill, project: project)
  }

  var body: some View {
    HStack(spacing: 14) {
      Image(systemName: project.iconSystemName)
        .foregroundStyle(.secondary)
        .font(.title3)
        .frame(width: 24)

      HStack(spacing: 8) {
        Text(project.name)
          .font(.body)
          .fontWeight(.medium)
          .lineLimit(1)
        Text("·")
          .foregroundStyle(.tertiary)
        PathText(project.skillsDirectory)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      InlineStatusLabel(status: status)

      Toggle("Installed", isOn: installBinding)
        .labelsHidden()
        .disabled(!status.allowsInstall)
    }
    .padding(16)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
  }

  private var installBinding: Binding<Bool> {
    Binding {
      status.isInstalled
    } set: { isOn in
      if isOn {
        store.install(skill: skill, into: project)
      } else {
        store.uninstall(skill: skill, from: project)
      }
    }
  }
}
