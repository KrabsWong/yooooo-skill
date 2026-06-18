import Foundation

public protocol SkillInstallTarget: Sendable {
  var id: String { get }
  var name: String { get }
  var skillsDirectory: String { get }
  var iconSystemName: String { get }
  var skillsDirectoryURL: URL { get }
}
