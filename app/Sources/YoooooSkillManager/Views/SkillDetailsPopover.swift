import SwiftUI
import YoooooSkillManagerCore

struct SkillDetailsTrigger<Content: View>: View {
  var skill: SkillInfo
  var content: () -> Content
  @State private var isShowingDetails = false

  init(skill: SkillInfo, @ViewBuilder content: @escaping () -> Content) {
    self.skill = skill
    self.content = content
  }

  var body: some View {
    Button {
      isShowingDetails = true
    } label: {
      content()
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("View details for \(skill.name)")
    .help("View full skill details")
    .popover(isPresented: $isShowingDetails) {
      SkillDetailsPopover(skill: skill)
    }
  }
}

private struct SkillDetailsPopover: View {
  var skill: SkillInfo

  private var metadataItems: [MetadataItem] {
    [
      MetadataItem(label: "", value: skill.source, tint: .secondary),
      MetadataItem(label: "", value: PathHelpers.compactHome(skill.path), tint: .secondary)
    ]
  }

  private var hasSupplementalMetadata: Bool {
    !skill.author.isEmpty || !skill.license.isEmpty || !skill.compatibility.isEmpty
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      VStack(alignment: .leading, spacing: 6) {
        Text(skill.name)
          .font(.title3)
          .fontWeight(.semibold)
          .lineLimit(2)
          .textSelection(.enabled)

        MetadataLine(items: metadataItems)
      }

      Divider()

      ScrollView {
        Text(skill.description.isEmpty ? "No description available." : skill.description)
          .font(.callout)
          .foregroundStyle(.secondary)
          .lineSpacing(3)
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .frame(maxHeight: 240)

      if hasSupplementalMetadata {
        Divider()

        VStack(alignment: .leading, spacing: 8) {
          if !skill.author.isEmpty {
            SkillDetailsMetadataRow(label: "Author", value: skill.author)
          }
          if !skill.license.isEmpty {
            SkillDetailsMetadataRow(label: "License", value: skill.license)
          }
          if !skill.compatibility.isEmpty {
            SkillDetailsMetadataRow(label: "Compatibility", value: skill.compatibility)
          }
        }
      }
    }
    .padding(16)
    .frame(width: 430, alignment: .leading)
  }
}

private struct SkillDetailsMetadataRow: View {
  var label: String
  var value: String

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      Text(label)
        .foregroundStyle(.secondary)
        .frame(width: 86, alignment: .leading)
      Text(value)
        .lineLimit(2)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .font(.callout)
  }
}
