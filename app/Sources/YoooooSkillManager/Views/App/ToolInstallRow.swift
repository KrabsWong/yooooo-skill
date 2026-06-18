import SwiftUI
import YoooooSkillManagerCore

struct ToolInstallRow: View {
  @Bindable var store: SkillManagerStore
  var skill: SkillInfo
  var tool: AgentTool

  private var status: SkillLinkStatus {
    store.status(skill: skill, tool: tool)
  }

  var body: some View {
    HStack(spacing: 14) {
      ToolIconView(tool: tool, size: 24)
        .frame(width: 24)

      HStack(spacing: 8) {
        Text(tool.name)
          .font(.body)
          .fontWeight(.medium)
          .lineLimit(1)
        Text("·")
          .foregroundStyle(.tertiary)
        PathText(tool.skillsDirectory)
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
        store.install(skill: skill, into: tool)
      } else {
        store.uninstall(skill: skill, from: tool)
      }
    }
  }
}
