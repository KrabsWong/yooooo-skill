import SwiftUI
import YoooooSkillManagerCore

enum SidebarSelection: Hashable {
  case tool(String)
  case skill(String)
  case project(String)
}

enum SidebarMode: String, CaseIterable, Identifiable {
  case apps
  case skills
  case projects

  var id: String {
    rawValue
  }

  var title: String {
    switch self {
    case .apps:
      return "Apps"
    case .skills:
      return "Skills"
    case .projects:
      return "Projects"
    }
  }
}

struct ContentView: View {
  @Bindable var store: SkillManagerStore
  @Environment(\.openSettings) private var openSettings
  @State private var selection: SidebarSelection?
  @State private var sidebarMode: SidebarMode = .apps
  @State private var searchText = ""

  var body: some View {
    NavigationSplitView {
      SidebarView(
        store: store,
        selection: $selection,
        mode: sidebarModeBinding,
        searchText: $searchText
      )
    } detail: {
      detailView
    }
    .toolbar {
      ToolbarItemGroup(placement: .primaryAction) {
        Button {
          store.reload()
        } label: {
          Label("Refresh", systemImage: "arrow.clockwise")
        }
        .help("Refresh")

        Button {
          openSettings()
        } label: {
          Label("Settings", systemImage: "gearshape")
        }
        .help("Settings")
      }
    }
  }

  @ViewBuilder
  private var detailView: some View {
    switch selection {
    case .none:
      WelcomeView()
    case let .tool(id):
      if let tool = store.tools.first(where: { $0.id == id }) {
        ToolDetailView(store: store, tool: tool)
      } else {
        WelcomeView()
      }
    case let .skill(id):
      if let skill = store.skills.first(where: { $0.id == id }) {
        SkillDetailView(store: store, skill: skill)
      } else {
        WelcomeView()
      }
    case let .project(id):
      if let project = store.projects.first(where: { $0.id == id }) {
        ProjectDetailView(store: store, project: project)
      } else {
        WelcomeView()
      }
    }
  }

  private var sidebarModeBinding: Binding<SidebarMode> {
    Binding {
      sidebarMode
    } set: { newMode in
      guard newMode != sidebarMode else {
        return
      }

      sidebarMode = newMode
      selection = nil
    }
  }
}
