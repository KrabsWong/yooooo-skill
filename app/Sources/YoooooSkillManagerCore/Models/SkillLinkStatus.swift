import Foundation

public enum SkillLinkStatus: Equatable, Sendable {
  case notInstalled
  case installed(URL)
  case linkedElsewhere(URL)
  case conflict(String)

  public var isInstalled: Bool {
    if case .installed = self {
      return true
    }

    return false
  }

  public var allowsInstall: Bool {
    if case .conflict = self {
      return false
    }

    return true
  }

  public var label: String {
    switch self {
    case .notInstalled:
      return "Not installed"
    case .installed:
      return "Installed"
    case .linkedElsewhere:
      return "Different link"
    case .conflict:
      return "Conflict"
    }
  }
}
