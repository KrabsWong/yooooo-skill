import SwiftUI
import YoooooSkillManagerCore

struct SidebarView: View {
  @Bindable var store: SkillManagerStore
  @Binding var selection: SidebarSelection?
  @Binding var mode: SidebarMode
  @Binding var searchText: String

  private var filteredTools: [AgentTool] {
    guard !searchText.isEmpty else {
      return store.tools
    }

    return store.tools.filter {
      $0.name.localizedCaseInsensitiveContains(searchText)
        || $0.skillsDirectory.localizedCaseInsensitiveContains(searchText)
    }
  }

  private var filteredSkills: [SkillInfo] {
    guard !searchText.isEmpty else {
      return store.skills
    }

    return store.skills.filter {
      $0.name.localizedCaseInsensitiveContains(searchText)
        || $0.description.localizedCaseInsensitiveContains(searchText)
        || $0.source.localizedCaseInsensitiveContains(searchText)
    }
  }

  private var filteredProjects: [ProjectTarget] {
    guard !searchText.isEmpty else {
      return store.projects
    }

    return store.projects.filter {
      $0.name.localizedCaseInsensitiveContains(searchText)
        || $0.rootPath.localizedCaseInsensitiveContains(searchText)
        || $0.skillsDirectory.localizedCaseInsensitiveContains(searchText)
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      Picker("Sidebar Mode", selection: $mode) {
        ForEach(SidebarMode.allCases) { mode in
          Text(mode.title).tag(mode)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .padding([.horizontal, .top], 10)
      .padding(.bottom, 6)

      List(selection: $selection) {
        switch mode {
        case .apps:
          Section("Apps") {
            ForEach(filteredTools) { tool in
              ToolSidebarRow(
                tool: tool,
                installedCount: store.installedSkills(for: tool).count,
                exists: store.isDirectoryPresent(for: tool)
              )
              .tag(SidebarSelection.tool(tool.id))
            }
          }
        case .skills:
          Section("Skills") {
            ForEach(filteredSkills) { skill in
              SkillSidebarRow(
                skill: skill,
                installedCount: store.installedTools(for: skill).count + store.installedProjects(for: skill).count
              )
              .tag(SidebarSelection.skill(skill.id))
            }
          }
        case .projects:
          Section("Projects") {
            ForEach(filteredProjects) { project in
              ProjectSidebarRow(
                project: project,
                installedCount: store.installedSkills(for: project).count,
                exists: store.isProjectRootPresent(for: project)
              )
              .tag(SidebarSelection.project(project.id))
            }
          }
        }
      }
      .listStyle(.sidebar)
    }
    .searchable(text: $searchText, placement: .sidebar)
  }
}

private struct SkillSidebarRow: View {
  var skill: SkillInfo
  var installedCount: Int

  var body: some View {
    HStack(spacing: 10) {
      SkillIconView(skill: skill, size: 16, usesCategoryTint: false)
        .frame(width: 16)

      VStack(alignment: .leading, spacing: 2) {
        Text(skill.name)
          .lineLimit(1)
        Text(installedCount == 0 ? skill.source : "\(installedCount) apps")
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
  }
}

private struct ProjectSidebarRow: View {
  var project: ProjectTarget
  var installedCount: Int
  var exists: Bool

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: project.iconSystemName)
        .foregroundStyle(.secondary)
        .frame(width: 16)

      VStack(alignment: .leading, spacing: 2) {
        Text(project.name)
          .lineLimit(1)
        Text(exists ? "\(installedCount) installed" : "Project missing")
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
  }
}
