import SwiftUI
import YoooooSkillManagerCore

struct ProjectDetailView: View {
  @Bindable var store: SkillManagerStore
  var project: ProjectTarget
  @State private var skillFilter: SkillInstallFilter = .all
  @State private var skillSearchText = ""

  private var installedSkills: [SkillInfo] {
    store.installedSkills(for: project)
  }

  private var filteredSkills: [SkillInfo] {
    store.skills.filter { skill in
      skill.matchesSearch(skillSearchText)
        && skillFilter.includes(store.status(skill: skill, project: project))
    }
  }

  private var metadataItems: [MetadataItem] {
    let conflictCount = store.conflicts(for: project)
    var items = [
      MetadataItem(label: "Project", value: PathHelpers.compactHome(project.rootPath)),
      MetadataItem(label: "Skills", value: PathHelpers.compactHome(project.skillsDirectory)),
      MetadataItem(label: "Installed", value: "\(installedSkills.count)/\(store.skills.count)")
    ]

    if conflictCount > 0 {
      items.append(MetadataItem(label: "Conflicts", value: "\(conflictCount)", tint: .red))
    }

    return items
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        VStack(alignment: .leading, spacing: 12) {
          HStack(alignment: .firstTextBaseline) {
            Label(project.name, systemImage: project.iconSystemName)
              .font(.largeTitle)
              .fontWeight(.semibold)
            Spacer()
            StatusBadge(
              title: store.isProjectRootPresent(for: project) ? "Registered" : "Missing",
              systemImage: store.isProjectRootPresent(for: project) ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
              tint: store.isProjectRootPresent(for: project) ? .green : .orange
            )
          }

          MetadataLine(items: metadataItems)
        }

        VStack(alignment: .leading, spacing: 14) {
          HStack(alignment: .firstTextBaseline) {
            Text("Skills")
              .font(.headline)
            Spacer()
            Text("\(filteredSkills.count) of \(store.skills.count)")
              .foregroundStyle(.secondary)
          }

          SkillListControls(filter: $skillFilter, searchText: $skillSearchText)

          if filteredSkills.isEmpty {
            EmptySkillFilterState()
          } else {
            LazyVStack(spacing: 10) {
              ForEach(filteredSkills) { skill in
                ProjectSkillInstallRow(store: store, skill: skill, project: project)
              }
            }
          }
        }
      }
      .padding(24)
      .frame(maxWidth: 980, alignment: .leading)
    }
  }
}

private struct ProjectSkillInstallRow: View {
  @Bindable var store: SkillManagerStore
  var skill: SkillInfo
  var project: ProjectTarget

  private var status: SkillLinkStatus {
    store.status(skill: skill, project: project)
  }

  var body: some View {
    HStack(spacing: 14) {
      SkillIconView(skill: skill, size: 19)
        .frame(width: 24)

      SkillDetailsTrigger(skill: skill) {
        VStack(alignment: .leading, spacing: 5) {
          Text(skill.name)
            .font(.body)
            .fontWeight(.medium)
          Text(skill.description.isEmpty ? skill.source : skill.description)
            .font(.callout)
            .foregroundStyle(.secondary)
            .lineSpacing(3)
            .lineLimit(2)
        }
      }

      Spacer()

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
