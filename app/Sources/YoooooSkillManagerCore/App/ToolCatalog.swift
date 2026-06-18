import Foundation

public enum ToolCatalog {
  public static func knownTools(
    homeDirectory: URL = PathHelpers.homeDirectory,
    environment: [String: String] = ProcessInfo.processInfo.environment,
    fileManager: FileManager = .default
  ) -> [AgentTool] {
    let codexHome = environment["CODEX_HOME"].map(PathHelpers.expandHome)
      ?? homeDirectory.appendingPathComponent(".codex").path

    return [
      knownTool(
        id: "claude-code",
        name: "Claude Code",
        icon: "app.badge",
        iconAsset: "claude",
        candidates: ["~/.claude/skills"],
        fileManager: fileManager
      ),
      knownTool(
        id: "codex-app",
        name: "Codex App",
        icon: "app.badge",
        iconAsset: "codex",
        candidates: ["\(codexHome)/skills", "~/.codex/skills"],
        fileManager: fileManager
      ),
      knownTool(
        id: "codex-cli",
        name: "Codex CLI",
        icon: "app.badge",
        iconAsset: "codex",
        candidates: ["\(codexHome)/skills", "~/.codex/skills"],
        fileManager: fileManager
      ),
      knownTool(
        id: "opencode",
        name: "OpenCode",
        icon: "app.badge",
        iconAsset: "opencode",
        candidates: ["~/.config/opencode/skills"],
        fileManager: fileManager
      ),
      knownTool(
        id: "pi-coding-agent",
        name: "Pi Coding Agent",
        icon: "app.badge",
        candidates: ["~/.pi/agent/skills"],
        fileManager: fileManager
      ),
      knownTool(
        id: "workbuddy",
        name: "WorkBuddy",
        icon: "app.badge",
        candidates: ["~/.workbuddy/skills", "~/.config/workbuddy/skills"],
        fileManager: fileManager
      ),
      knownTool(
        id: "codebuddy-ide",
        name: "CodeBuddy IDE",
        icon: "app.badge",
        iconAsset: "codebuddy",
        candidates: ["~/.codebuddy/skills", "~/.config/codebuddy/skills"],
        fileManager: fileManager
      ),
      knownTool(
        id: "codebuddy-cli",
        name: "CodeBuddy CLI",
        icon: "app.badge",
        iconAsset: "codebuddy",
        candidates: ["~/.codebuddy-cli/skills", "~/.config/codebuddy/skills", "~/.codebuddy/skills"],
        fileManager: fileManager
      ),
      knownTool(
        id: "kimi-cli",
        name: "Kimi CLI",
        icon: "app.badge",
        iconAsset: "kimi",
        candidates: ["~/.kimi/skills", "~/.config/kimi/skills"],
        fileManager: fileManager
      ),
      knownTool(
        id: "antigravety-cli",
        name: "Antigravety CLI",
        icon: "app.badge",
        iconAsset: "antigravity",
        candidates: ["~/.antigravety/skills", "~/.config/antigravety/skills"],
        fileManager: fileManager
      )
    ]
  }

  private static func knownTool(
    id: String,
    name: String,
    icon: String,
    iconAsset: String? = nil,
    candidates: [String],
    fileManager: FileManager
  ) -> AgentTool {
    let standardizedCandidates = candidates.map(PathHelpers.standardizedPath)
    let detected = standardizedCandidates.first { path in
      var isDirectory: ObjCBool = false
      return fileManager.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    return AgentTool(
      id: id,
      name: name,
      kind: .known,
      skillsDirectory: detected ?? standardizedCandidates[0],
      candidateDirectories: standardizedCandidates,
      note: detected == nil ? "Using default candidate" : "Detected",
      iconSystemName: icon,
      iconAssetName: iconAsset
    )
  }
}
