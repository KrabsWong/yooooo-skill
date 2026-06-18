import AppKit
import SwiftUI
import YoooooSkillManagerCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
  }
}

@main
struct YoooooSkillManagerApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @State private var store = SkillManagerStore(defaultSkillsRoot: DefaultSkillRootResolver.resolve())

  var body: some Scene {
    WindowGroup("Yooooo Skill Manager", id: "main") {
      ContentView(store: store)
        .frame(minWidth: 980, minHeight: 640)
    }
    .commands {
      CommandMenu("Skills") {
        Button("Refresh") {
          store.reload()
        }
        .keyboardShortcut("r")
      }
    }

    Settings {
      SettingsView(store: store)
    }
  }
}
