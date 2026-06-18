import Foundation

public enum DefaultSkillRootResolver {
  public static func resolve(bundle: Bundle = .main, fileManager: FileManager = .default) -> String {
    var candidates: [URL] = []

    if let bundledRoot = bundle.object(forInfoDictionaryKey: "YoooooDefaultSkillRoot") as? String, !bundledRoot.isEmpty {
      candidates.append(URL(fileURLWithPath: PathHelpers.expandHome(bundledRoot), isDirectory: true))
    }

    candidates.append(bundle.bundleURL.deletingLastPathComponent().deletingLastPathComponent())
    candidates.append(URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true))
    candidates.append(PathHelpers.homeDirectory)

    for candidate in candidates {
      if looksLikeSkillRoot(candidate, fileManager: fileManager) {
        return candidate.standardizedFileURL.path
      }
    }

    return PathHelpers.homeDirectory.path
  }

  private static func looksLikeSkillRoot(_ url: URL, fileManager: FileManager) -> Bool {
    guard let entries = try? fileManager.contentsOfDirectory(
      at: url,
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles]
    ) else {
      return false
    }

    if entries.contains(where: { fileManager.fileExists(atPath: $0.appendingPathComponent("SKILL.md").path) }) {
      return true
    }

    return fileManager.fileExists(atPath: url.appendingPathComponent("external").path)
  }
}
