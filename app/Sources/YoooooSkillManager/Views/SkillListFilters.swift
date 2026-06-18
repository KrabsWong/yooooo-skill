import SwiftUI
import YoooooSkillManagerCore

enum SkillInstallFilter: String, CaseIterable, Identifiable {
  case all
  case installed
  case notInstalled

  var id: String {
    rawValue
  }

  var title: String {
    switch self {
    case .all:
      return "All"
    case .installed:
      return "Installed"
    case .notInstalled:
      return "Not Installed"
    }
  }

  func includes(_ status: SkillLinkStatus) -> Bool {
    switch self {
    case .all:
      return true
    case .installed:
      return status.isInstalled
    case .notInstalled:
      return !status.isInstalled
    }
  }
}

struct SkillListControls: View {
  @Binding var filter: SkillInstallFilter
  @Binding var searchText: String

  var body: some View {
    HStack(spacing: 12) {
      InstallFilterPicker(filter: $filter, width: 360)

      Spacer()

      HStack(spacing: 6) {
        Image(systemName: "magnifyingglass")
          .foregroundStyle(.secondary)
        TextField("Search skills", text: $searchText)
          .font(.body)
          .textFieldStyle(.plain)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 9)
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
      .frame(width: 300)
    }
  }
}

struct InstallFilterPicker: View {
  @Binding var filter: SkillInstallFilter
  var width: CGFloat

  var body: some View {
    Picker("Filter", selection: $filter) {
      ForEach(SkillInstallFilter.allCases) { filter in
        Text(filter.title).tag(filter)
      }
    }
    .pickerStyle(.segmented)
    .controlSize(.large)
    .frame(width: width, alignment: .leading)
  }
}

struct EmptySkillFilterState: View {
  var body: some View {
    ContentUnavailableView(
      "No Skills",
      systemImage: "line.3.horizontal.decrease.circle",
      description: Text("No skills match the current filter.")
    )
    .frame(maxWidth: .infinity)
    .padding(.vertical, 40)
  }
}

extension SkillInfo {
  func matchesSearch(_ query: String) -> Bool {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      return true
    }

    return name.localizedCaseInsensitiveContains(trimmed)
      || description.localizedCaseInsensitiveContains(trimmed)
      || source.localizedCaseInsensitiveContains(trimmed)
      || path.localizedCaseInsensitiveContains(trimmed)
  }
}
