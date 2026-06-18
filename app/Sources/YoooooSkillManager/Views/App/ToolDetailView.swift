import SwiftUI
import YoooooSkillManagerCore

struct ToolDetailView: View {
  @Bindable var store: SkillManagerStore
  var tool: AgentTool
  @State private var skillFilter: SkillInstallFilter = .all
  @State private var skillSearchText = ""

  private var installedSkills: [SkillInfo] {
    store.installedSkills(for: tool)
  }

  private var filteredSkills: [SkillInfo] {
    store.skills.filter { skill in
      skill.matchesSearch(skillSearchText)
        && skillFilter.includes(store.status(skill: skill, tool: tool))
    }
  }

  private var metadataItems: [MetadataItem] {
    let conflictCount = store.conflicts(for: tool)
    var items = [
      MetadataItem(label: "Directory", value: PathHelpers.compactHome(tool.skillsDirectory)),
      MetadataItem(label: "Installed", value: "\(installedSkills.count)/\(store.skills.count)"),
      MetadataItem(label: "Type", value: tool.isCustom ? "Custom" : "Preset")
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
            HStack(spacing: 12) {
              ToolIconView(tool: tool, size: 34)
              Text(tool.name)
                .font(.largeTitle)
                .fontWeight(.semibold)
            }
            Spacer()
            StatusBadge(
              title: store.isDirectoryPresent(for: tool) ? "Detected" : "Default",
              systemImage: store.isDirectoryPresent(for: tool) ? "checkmark.circle.fill" : "circle",
              tint: store.isDirectoryPresent(for: tool) ? .green : .secondary
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
                SkillInstallRow(store: store, skill: skill, tool: tool)
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

private struct SkillInstallRow: View {
  @Bindable var store: SkillManagerStore
  var skill: SkillInfo
  var tool: AgentTool

  private var status: SkillLinkStatus {
    store.status(skill: skill, tool: tool)
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
        store.install(skill: skill, into: tool)
      } else {
        store.uninstall(skill: skill, from: tool)
      }
    }
  }
}
