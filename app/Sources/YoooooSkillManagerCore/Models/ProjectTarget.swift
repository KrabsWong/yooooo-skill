import Foundation

public struct ProjectTarget: Identifiable, Hashable, Codable, Sendable, SkillInstallTarget {
  public var id: String
  public var name: String
  public var rootPath: String
  public var iconSystemName: String

  public init(
    id: String = "project-\(UUID().uuidString)",
    name: String,
    rootPath: String,
    iconSystemName: String = "folder.badge.gearshape"
  ) {
    self.id = id
    self.name = name
    self.rootPath = PathHelpers.standardizedPath(rootPath)
    self.iconSystemName = iconSystemName
  }

  public var skillsDirectory: String {
    URL(fileURLWithPath: rootPath, isDirectory: true)
      .appendingPathComponent(".agents", isDirectory: true)
      .appendingPathComponent("skills", isDirectory: true)
      .standardizedFileURL
      .path
  }

  public var rootURL: URL {
    URL(fileURLWithPath: rootPath, isDirectory: true).standardizedFileURL
  }

  public var skillsDirectoryURL: URL {
    URL(fileURLWithPath: skillsDirectory, isDirectory: true).standardizedFileURL
  }
}
