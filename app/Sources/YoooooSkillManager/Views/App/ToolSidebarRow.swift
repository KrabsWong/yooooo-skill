import SwiftUI
import YoooooSkillManagerCore

struct ToolSidebarRow: View {
  var tool: AgentTool
  var installedCount: Int
  var exists: Bool

  var body: some View {
    HStack(spacing: 10) {
      ToolIconView(tool: tool, size: 16)
        .frame(width: 16)

      VStack(alignment: .leading, spacing: 2) {
        Text(tool.name)
          .lineLimit(1)
        Text(exists ? "\(installedCount) installed" : "Directory missing")
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
  }
}
