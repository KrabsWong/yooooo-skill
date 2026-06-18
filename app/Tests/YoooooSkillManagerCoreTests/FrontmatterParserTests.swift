import XCTest
@testable import YoooooSkillManagerCore

final class FrontmatterParserTests: XCTestCase {
  func testParsesScalarAndBlockValues() {
    let content = """
    ---
    name: sample-skill
    description: >
      First sentence.
      Second sentence.
    author: "Skill Author"
    license: AGPL-3.0-only
    ---

    # Sample
    """

    let metadata = FrontmatterParser.parse(content)

    XCTAssertEqual(metadata["name"], "sample-skill")
    XCTAssertEqual(metadata["description"], "First sentence. Second sentence.")
    XCTAssertEqual(metadata["author"], "Skill Author")
    XCTAssertEqual(metadata["license"], "AGPL-3.0-only")
  }

  func testReturnsEmptyMetadataWhenNoFrontmatterExists() {
    XCTAssertEqual(FrontmatterParser.parse("# Title"), [:])
  }
}
