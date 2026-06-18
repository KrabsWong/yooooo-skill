import Foundation

func makeTemporaryDirectory() throws -> URL {
  let url = FileManager.default.temporaryDirectory
    .appendingPathComponent("YoooooSkillManagerTests")
    .appendingPathComponent(UUID().uuidString, isDirectory: true)
  try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
  return url
}

func writeSkill(at url: URL, frontmatter: String) throws {
  try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
  let content = """
  ---
  \(frontmatter)
  ---

  # \(url.lastPathComponent)
  """
  try content.write(to: url.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
}
