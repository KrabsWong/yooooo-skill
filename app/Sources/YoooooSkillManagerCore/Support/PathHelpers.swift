import Foundation

public enum PathHelpers {
  public static var homeDirectory: URL {
    FileManager.default.homeDirectoryForCurrentUser
  }

  public static func expandHome(_ path: String) -> String {
    if path == "~" {
      return homeDirectory.path
    }

    if path.hasPrefix("~/") {
      return homeDirectory.appendingPathComponent(String(path.dropFirst(2))).path
    }

    return path
  }

  public static func compactHome(_ path: String) -> String {
    let home = homeDirectory.path
    if path == home {
      return "~"
    }

    if path.hasPrefix(home + "/") {
      return "~/" + path.dropFirst(home.count + 1)
    }

    return path
  }

  public static func standardizedPath(_ path: String) -> String {
    URL(fileURLWithPath: expandHome(path)).standardizedFileURL.path
  }

  public static func destinationOfSymbolicLink(at url: URL, fileManager: FileManager = .default) -> URL? {
    guard let destination = try? fileManager.destinationOfSymbolicLink(atPath: url.path) else {
      return nil
    }

    let destinationURL = destination.hasPrefix("/")
      ? URL(fileURLWithPath: destination)
      : url.deletingLastPathComponent().appendingPathComponent(destination)

    return destinationURL.standardizedFileURL.resolvingSymlinksInPath()
  }

  public static func fileKind(at url: URL, fileManager: FileManager = .default) -> String? {
    var isDirectory: ObjCBool = false
    guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
      return nil
    }

    return isDirectory.boolValue ? "directory" : "file"
  }
}
