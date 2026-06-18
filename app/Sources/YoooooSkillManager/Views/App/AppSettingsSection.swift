import SwiftUI
import YoooooSkillManagerCore

struct AppSettingsSection: View {
  @Bindable var store: SkillManagerStore
  @Binding var showingAddTool: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      SettingsSectionHeader(title: "Apps")

      if store.tools.isEmpty {
        SettingsEmptyState(text: "No apps available.")
      } else {
        VStack(spacing: 8) {
          ForEach(store.tools) { tool in
            SettingsListRow(
              title: tool.name,
              detail: tool.skillsDirectory,
              iconSystemName: tool.iconSystemName,
              iconAssetName: tool.iconAssetName,
              badge: tool.isCustom ? "Custom" : "Built-in",
              remove: tool.isCustom ? { store.removeCustomTool(id: tool.id) } : nil
            )
          }
        }
      }

      Button {
        showingAddTool = true
      } label: {
        Label("Add App", systemImage: "plus")
      }
    }
  }
}
