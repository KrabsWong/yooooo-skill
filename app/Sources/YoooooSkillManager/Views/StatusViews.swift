import SwiftUI
import YoooooSkillManagerCore

struct DetailSurface<Content: View>: View {
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      content
    }
    .font(.body)
    .padding(16)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
  }
}

struct PathText: View {
  var path: String

  init(_ path: String) {
    self.path = path
  }

  var body: some View {
    Text(PathHelpers.compactHome(path))
      .font(.callout)
      .foregroundStyle(.secondary)
      .lineLimit(1)
      .truncationMode(.middle)
      .textSelection(.enabled)
  }
}

struct MetadataItem {
  var label: String
  var value: String
  var tint: Color?
}

struct MetadataLine: View {
  var items: [MetadataItem]

  var body: some View {
    HStack(spacing: 7) {
      ForEach(Array(items.enumerated()), id: \.offset) { index, item in
        if index > 0 {
          Text("·")
            .foregroundStyle(.tertiary)
        }

        HStack(spacing: 4) {
          if !item.label.isEmpty {
            Text(item.label)
              .foregroundStyle(.secondary)
          }
          Text(item.value)
            .foregroundStyle(item.tint ?? Color.primary.opacity(0.72))
            .lineLimit(1)
            .truncationMode(.middle)
        }
      }
    }
    .font(.callout)
    .lineLimit(1)
    .textSelection(.enabled)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct StatTile: View {
  var title: String
  var value: String
  var systemImage: String

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Image(systemName: systemImage)
          .foregroundStyle(.secondary)
        Spacer()
      }
      Text(value)
        .font(.title)
        .fontWeight(.semibold)
      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
  }
}

struct StatusBadge: View {
  var title: String
  var systemImage: String
  var tint: Color

  init(title: String, systemImage: String, tint: Color) {
    self.title = title
    self.systemImage = systemImage
    self.tint = tint
  }

  init(status: SkillLinkStatus) {
    switch status {
    case .notInstalled:
      self.init(title: status.label, systemImage: "circle", tint: .secondary)
    case .installed:
      self.init(title: status.label, systemImage: "checkmark.circle.fill", tint: .green)
    case .linkedElsewhere:
      self.init(title: status.label, systemImage: "arrow.triangle.2.circlepath", tint: .orange)
    case .conflict:
      self.init(title: status.label, systemImage: "exclamationmark.triangle.fill", tint: .red)
    }
  }

  var body: some View {
    Label(title, systemImage: systemImage)
      .font(.callout)
      .foregroundStyle(tint)
      .labelStyle(.titleAndIcon)
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(tint.opacity(0.12), in: Capsule())
  }
}

struct InlineStatusLabel: View {
  var status: SkillLinkStatus

  private var shouldShowStatus: Bool {
    switch status {
    case .notInstalled, .installed:
      return false
    case .linkedElsewhere, .conflict:
      return true
    }
  }

  private var systemImage: String {
    switch status {
    case .notInstalled:
      return "circle"
    case .installed:
      return "checkmark.circle.fill"
    case .linkedElsewhere:
      return "arrow.triangle.2.circlepath"
    case .conflict:
      return "exclamationmark.triangle.fill"
    }
  }

  private var tint: Color {
    switch status {
    case .notInstalled:
      return .secondary
    case .installed:
      return .green
    case .linkedElsewhere:
      return .orange
    case .conflict:
      return .red
    }
  }

  private var statusContent: some View {
    HStack(spacing: 5) {
      Image(systemName: systemImage)
        .font(.system(size: 11, weight: .medium))
      Text(status.label)
        .font(.callout)
    }
    .lineLimit(1)
    .fixedSize(horizontal: true, vertical: false)
    .accessibilityElement(children: .combine)
  }

  var body: some View {
    if shouldShowStatus {
      statusContent
        .foregroundStyle(tint)
    }
  }
}
