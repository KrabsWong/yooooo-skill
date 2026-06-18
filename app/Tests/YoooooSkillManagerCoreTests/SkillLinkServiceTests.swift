import XCTest
@testable import YoooooSkillManagerCore

final class SkillLinkServiceTests: XCTestCase {
  func testInstallAndUninstallSymlink() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let skillDirectory = root.appendingPathComponent("sample-skill")
    try writeSkill(at: skillDirectory, frontmatter: "name: sample-skill")

    let targetDirectory = root.appendingPathComponent("target-skills")
    let skill = SkillInfo(name: "sample-skill", path: skillDirectory.path)
    let tool = AgentTool(
      id: "test-tool",
      name: "Test Tool",
      kind: .custom,
      skillsDirectory: targetDirectory.path
    )
    let service = SkillLinkService()

    XCTAssertEqual(service.status(skill: skill, in: tool), .notInstalled)

    _ = try service.install(skill: skill, into: tool)

    guard case .installed = service.status(skill: skill, in: tool) else {
      return XCTFail("Expected installed status")
    }

    let destination = targetDirectory.appendingPathComponent("sample-skill")
    let linkTarget = try FileManager.default.destinationOfSymbolicLink(atPath: destination.path)
    XCTAssertEqual(URL(fileURLWithPath: linkTarget).standardizedFileURL.path, skillDirectory.standardizedFileURL.path)

    _ = try service.uninstall(skill: skill, from: tool)
    XCTAssertEqual(service.status(skill: skill, in: tool), .notInstalled)
  }

  func testInstallDoesNotOverwriteRealDirectory() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let skillDirectory = root.appendingPathComponent("sample-skill")
    let targetDirectory = root.appendingPathComponent("target-skills")
    try writeSkill(at: skillDirectory, frontmatter: "name: sample-skill")
    try FileManager.default.createDirectory(
      at: targetDirectory.appendingPathComponent("sample-skill"),
      withIntermediateDirectories: true
    )

    let skill = SkillInfo(name: "sample-skill", path: skillDirectory.path)
    let tool = AgentTool(
      id: "test-tool",
      name: "Test Tool",
      kind: .custom,
      skillsDirectory: targetDirectory.path
    )

    XCTAssertThrowsError(try SkillLinkService().install(skill: skill, into: tool)) { error in
      guard case SkillLinkError.conflict = error else {
        return XCTFail("Expected conflict, got \(error)")
      }
    }
  }

  func testProjectTargetInstallsIntoProjectAgentsSkillsDirectory() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let skillDirectory = root.appendingPathComponent("sample-skill")
    let projectRoot = root.appendingPathComponent("sample-project")
    try writeSkill(at: skillDirectory, frontmatter: "name: sample-skill")
    try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)

    let skill = SkillInfo(name: "sample-skill", path: skillDirectory.path)
    let project = ProjectTarget(name: "Sample Project", rootPath: projectRoot.path)
    let service = SkillLinkService()

    _ = try service.install(skill: skill, into: project)

    let destination = projectRoot
      .appendingPathComponent(".agents")
      .appendingPathComponent("skills")
      .appendingPathComponent("sample-skill")
    let linkTarget = try FileManager.default.destinationOfSymbolicLink(atPath: destination.path)

    XCTAssertEqual(
      project.skillsDirectory,
      projectRoot
        .appendingPathComponent(".agents")
        .appendingPathComponent("skills")
        .standardizedFileURL
        .path
    )
    XCTAssertEqual(URL(fileURLWithPath: linkTarget).standardizedFileURL.path, skillDirectory.standardizedFileURL.path)
  }
}
