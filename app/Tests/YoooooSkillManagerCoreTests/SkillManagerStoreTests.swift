import XCTest
@testable import YoooooSkillManagerCore

final class SkillManagerStoreTests: XCTestCase {
  func testPersistsRegisteredProjects() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let projectRoot = root.appendingPathComponent("project-a")
    try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)

    let suiteName = "YoooooSkillManagerTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)

    let store = SkillManagerStore(
      defaults: defaults,
      defaultSkillsRoot: root.path
    )
    store.addProject(name: "", rootPath: projectRoot.path)

    let reloadedStore = SkillManagerStore(
      defaults: defaults,
      defaultSkillsRoot: root.path
    )

    XCTAssertEqual(reloadedStore.projects.count, 1)
    XCTAssertEqual(reloadedStore.projects.first?.name, "project-a")
    XCTAssertEqual(
      reloadedStore.projects.first?.skillsDirectory,
      projectRoot
        .appendingPathComponent(".agents")
        .appendingPathComponent("skills")
        .path
    )
  }
}
