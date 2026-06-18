import Foundation

public struct SkillInfo: Identifiable, Hashable, Codable, Sendable {
  public var name: String
  public var description: String
  public var author: String
  public var license: String
  public var compatibility: String
  public var origin: String
  public var source: String
  public var path: String

  public init(
    name: String,
    description: String = "",
    author: String = "",
    license: String = "",
    compatibility: String = "",
    origin: String = "local",
    source: String = "local",
    path: String
  ) {
    self.name = name
    self.description = description
    self.author = author
    self.license = license
    self.compatibility = compatibility
    self.origin = origin
    self.source = source
    self.path = PathHelpers.standardizedPath(path)
  }

  public var id: String {
    path
  }

  public var url: URL {
    URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
  }

  public var directoryName: String {
    url.lastPathComponent
  }
}
