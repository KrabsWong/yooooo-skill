import Foundation

public struct AgentTool: Identifiable, Hashable, Codable, Sendable, SkillInstallTarget {
  public enum Kind: String, Codable, Sendable {
    case known
    case custom
  }

  public var id: String
  public var name: String
  public var kind: Kind
  public var skillsDirectory: String
  public var candidateDirectories: [String]
  public var note: String
  public var iconSystemName: String
  public var iconAssetName: String?

  public init(
    id: String,
    name: String,
    kind: Kind,
    skillsDirectory: String,
    candidateDirectories: [String] = [],
    note: String = "",
    iconSystemName: String = "app.badge",
    iconAssetName: String? = nil
  ) {
    self.id = id
    self.name = name
    self.kind = kind
    self.skillsDirectory = PathHelpers.standardizedPath(skillsDirectory)
    self.candidateDirectories = candidateDirectories.map(PathHelpers.standardizedPath)
    self.note = note
    self.iconSystemName = iconSystemName
    self.iconAssetName = iconAssetName
  }

  public var isCustom: Bool {
    kind == .custom
  }

  public var skillsDirectoryURL: URL {
    URL(fileURLWithPath: PathHelpers.expandHome(skillsDirectory), isDirectory: true)
      .standardizedFileURL
  }
}
