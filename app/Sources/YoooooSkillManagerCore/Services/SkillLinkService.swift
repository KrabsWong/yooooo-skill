import Foundation

public struct LinkOperationResult: Equatable, Sendable {
  public var title: String
  public var detail: String

  public init(title: String, detail: String) {
    self.title = title
    self.detail = detail
  }
}

public enum SkillLinkError: LocalizedError, Equatable {
  case conflict(destination: String, kind: String)
  case linkedElsewhere(destination: String, source: String)

  public var errorDescription: String? {
    switch self {
    case let .conflict(destination, kind):
      return "\(destination) already exists as a \(kind)."
    case let .linkedElsewhere(destination, source):
      return "\(destination) links to \(source)."
    }
  }
}

public struct SkillLinkService: Sendable {
  public init() {}

  public func status<Target: SkillInstallTarget>(
    skill: SkillInfo,
    in target: Target,
    fileManager: FileManager = .default
  ) -> SkillLinkStatus {
    let destination = destinationURL(for: skill, target: target)

    if let linkTarget = PathHelpers.destinationOfSymbolicLink(at: destination, fileManager: fileManager) {
      if samePath(linkTarget, skill.url) {
        return .installed(linkTarget)
      }

      return .linkedElsewhere(linkTarget)
    }

    if let kind = PathHelpers.fileKind(at: destination, fileManager: fileManager) {
      return .conflict(kind)
    }

    return .notInstalled
  }

  public func install<Target: SkillInstallTarget>(
    skill: SkillInfo,
    into target: Target,
    fileManager: FileManager = .default
  ) throws -> LinkOperationResult {
    let targetDirectory = target.skillsDirectoryURL
    let destination = destinationURL(for: skill, target: target)
    try fileManager.createDirectory(at: targetDirectory, withIntermediateDirectories: true)

    switch status(skill: skill, in: target, fileManager: fileManager) {
    case .installed:
      return LinkOperationResult(
        title: "Already installed",
        detail: "\(skill.name) is already linked in \(target.name)."
      )
    case .linkedElsewhere:
      try fileManager.removeItem(at: destination)
      try fileManager.createSymbolicLink(at: destination, withDestinationURL: skill.url)
      return LinkOperationResult(
        title: "Updated link",
        detail: "\(skill.name) now points to \(skill.path)."
      )
    case let .conflict(kind):
      throw SkillLinkError.conflict(destination: destination.path, kind: kind)
    case .notInstalled:
      try fileManager.createSymbolicLink(at: destination, withDestinationURL: skill.url)
      return LinkOperationResult(
        title: "Installed",
        detail: "\(skill.name) linked into \(target.name)."
      )
    }
  }

  public func uninstall<Target: SkillInstallTarget>(
    skill: SkillInfo,
    from target: Target,
    fileManager: FileManager = .default
  ) throws -> LinkOperationResult {
    let destination = destinationURL(for: skill, target: target)

    switch status(skill: skill, in: target, fileManager: fileManager) {
    case .installed:
      try fileManager.removeItem(at: destination)
      return LinkOperationResult(
        title: "Removed",
        detail: "\(skill.name) was removed from \(target.name)."
      )
    case .notInstalled:
      return LinkOperationResult(
        title: "Not installed",
        detail: "\(skill.name) is not linked in \(target.name)."
      )
    case let .linkedElsewhere(source):
      throw SkillLinkError.linkedElsewhere(destination: destination.path, source: source.path)
    case let .conflict(kind):
      throw SkillLinkError.conflict(destination: destination.path, kind: kind)
    }
  }

  public func destinationURL<Target: SkillInstallTarget>(for skill: SkillInfo, target: Target) -> URL {
    target.skillsDirectoryURL.appendingPathComponent(skill.name, isDirectory: true)
  }

  private func samePath(_ left: URL, _ right: URL) -> Bool {
    left.standardizedFileURL.resolvingSymlinksInPath().path == right.standardizedFileURL.resolvingSymlinksInPath().path
  }
}
