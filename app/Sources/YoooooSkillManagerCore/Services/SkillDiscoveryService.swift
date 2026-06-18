import Foundation

public struct SkillDiscoveryService: Sendable {
  public var maxDepth: Int
  public var skippedDirectoryNames: Set<String>

  public init(
    maxDepth: Int = 8,
    skippedDirectoryNames: Set<String> = [".git", ".swiftpm", ".build", "node_modules", "dist", "bin"]
  ) {
    self.maxDepth = maxDepth
    self.skippedDirectoryNames = skippedDirectoryNames
  }

  public func discoverSkills(in rootURL: URL, fileManager: FileManager = .default) throws -> [SkillInfo] {
    let root = rootURL.standardizedFileURL
    var skillDirectories: [URL] = []
    try walk(root, root: root, depth: 0, found: &skillDirectories, fileManager: fileManager)

    return try skillDirectories
      .map { try buildSkill(at: $0, root: root) }
      .sorted { left, right in
        left.name.localizedStandardCompare(right.name) == .orderedAscending
      }
  }

  private func walk(_ url: URL, root: URL, depth: Int, found: inout [URL], fileManager: FileManager) throws {
    guard depth <= maxDepth else {
      return
    }

    if hasSkillFile(url, fileManager: fileManager) {
      found.append(url.standardizedFileURL)
      return
    }

    let entries = try fileManager.contentsOfDirectory(
      at: url,
      includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
      options: [.skipsHiddenFiles]
    )

    for entry in entries {
      guard !skippedDirectoryNames.contains(entry.lastPathComponent) else {
        continue
      }

      let values = try entry.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
      guard values.isDirectory == true, values.isSymbolicLink != true else {
        continue
      }

      try walk(entry, root: root, depth: depth + 1, found: &found, fileManager: fileManager)
    }
  }

  private func hasSkillFile(_ url: URL, fileManager: FileManager) -> Bool {
    var isDirectory: ObjCBool = false
    let skillFile = url.appendingPathComponent("SKILL.md")
    return fileManager.fileExists(atPath: skillFile.path, isDirectory: &isDirectory) && !isDirectory.boolValue
  }

  private func buildSkill(at url: URL, root: URL) throws -> SkillInfo {
    let skillFile = url.appendingPathComponent("SKILL.md")
    let content = try String(contentsOf: skillFile, encoding: .utf8)
    let metadata = FrontmatterParser.parse(content)
    let source = sourceName(for: url, root: root)

    return SkillInfo(
      name: metadata["name"] ?? url.lastPathComponent,
      description: metadata["description"] ?? "",
      author: metadata["author"] ?? metadata["authors"] ?? "",
      license: metadata["license"] ?? "",
      compatibility: metadata["compatibility"] ?? "",
      origin: source.origin,
      source: source.label,
      path: url.path
    )
  }

  private func sourceName(for url: URL, root: URL) -> (origin: String, label: String) {
    let relativePath = url.standardizedFileURL.path.replacingOccurrences(of: root.standardizedFileURL.path + "/", with: "")
    let parts = relativePath.split(separator: "/").map(String.init)

    if parts.first == "external", parts.count >= 3 {
      return ("external", "\(parts[1])/\(parts[2])")
    }

    return ("local", "local")
  }
}
