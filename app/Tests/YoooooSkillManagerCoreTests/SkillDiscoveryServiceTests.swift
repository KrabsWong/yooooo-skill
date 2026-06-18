import XCTest
@testable import YoooooSkillManagerCore

final class SkillDiscoveryServiceTests: XCTestCase {
  func testDiscoversLocalAndExternalSkills() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    try writeSkill(
      at: root.appendingPathComponent("local-skill"),
      frontmatter: """
      name: local-skill
      description: Local description.
      author: Local Author
      """
    )
    try writeSkill(
      at: root.appendingPathComponent("external/acme/remote-skill"),
      frontmatter: """
      name: remote-skill
      description: Remote description.
      """
    )
    try writeSkill(
      at: root.appendingPathComponent("node_modules/ignored-skill"),
      frontmatter: "name: ignored-skill"
    )

    let skills = try SkillDiscoveryService().discoverSkills(in: root)

    XCTAssertEqual(skills.map(\.name), ["local-skill", "remote-skill"])
    XCTAssertEqual(skills.first(where: { $0.name == "local-skill" })?.author, "Local Author")
    XCTAssertEqual(skills.first(where: { $0.name == "remote-skill" })?.origin, "external")
    XCTAssertEqual(skills.first(where: { $0.name == "remote-skill" })?.source, "acme/remote-skill")
  }
}
