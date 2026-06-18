import Foundation
import Observation

@Observable
public final class SkillManagerStore {
  public var skillsRootPath: String
  public private(set) var skills: [SkillInfo] = []
  public private(set) var tools: [AgentTool] = []
  public private(set) var projects: [ProjectTarget] = []
  public private(set) var lastMessage: String?

  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored private let fileManager: FileManager
  @ObservationIgnored private let discoveryService: SkillDiscoveryService
  @ObservationIgnored private let linkService: SkillLinkService
  @ObservationIgnored private var customTools: [AgentTool] = []

  @ObservationIgnored private let rootPathKey = "YoooooSkillManager.skillsRootPath"
  @ObservationIgnored private let customToolsKey = "YoooooSkillManager.customTools"
  @ObservationIgnored private let projectsKey = "YoooooSkillManager.projects"

  public init(
    defaults: UserDefaults = .standard,
    fileManager: FileManager = .default,
    defaultSkillsRoot: String? = nil,
    discoveryService: SkillDiscoveryService = SkillDiscoveryService(),
    linkService: SkillLinkService = SkillLinkService()
  ) {
    self.defaults = defaults
    self.fileManager = fileManager
    self.discoveryService = discoveryService
    self.linkService = linkService
    self.skillsRootPath = defaults.string(forKey: rootPathKey)
      ?? defaultSkillsRoot
      ?? DefaultSkillRootResolver.resolve(fileManager: fileManager)
    self.customTools = Self.loadCustomTools(defaults: defaults, key: customToolsKey)
    self.projects = Self.loadProjects(defaults: defaults, key: projectsKey)
    refreshTools()
    reload()
  }

  public func reload() {
    do {
      let rootURL = URL(fileURLWithPath: PathHelpers.expandHome(skillsRootPath), isDirectory: true)
      skills = try discoveryService.discoverSkills(in: rootURL, fileManager: fileManager)
      refreshTools()
      lastMessage = "Found \(skills.count) skills."
    } catch {
      skills = []
      refreshTools()
      lastMessage = error.localizedDescription
    }
  }

  public func report(_ message: String) {
    lastMessage = message
  }

  public func setSkillsRoot(_ path: String) {
    skillsRootPath = PathHelpers.standardizedPath(path)
    defaults.set(skillsRootPath, forKey: rootPathKey)
    reload()
  }

  public func addCustomTool(name: String, skillsDirectory: String) {
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedDirectory = skillsDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty, !trimmedDirectory.isEmpty else {
      lastMessage = "Custom app name and directory are required."
      return
    }

    let id = "custom-\(UUID().uuidString)"
    customTools.append(
      AgentTool(
        id: id,
        name: trimmedName,
        kind: .custom,
        skillsDirectory: trimmedDirectory,
        iconSystemName: "app.connected.to.app.below.fill"
      )
    )
    saveCustomTools()
    refreshTools()
    lastMessage = "Added \(trimmedName)."
  }

  public func removeCustomTool(id: String) {
    guard let tool = customTools.first(where: { $0.id == id }) else {
      return
    }

    customTools.removeAll { $0.id == id }
    saveCustomTools()
    refreshTools()
    lastMessage = "Removed \(tool.name)."
  }

  public func addProject(name: String, rootPath: String) {
    let trimmedRootPath = rootPath.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedRootPath.isEmpty else {
      lastMessage = "Project directory is required."
      return
    }

    let rootURL = URL(fileURLWithPath: PathHelpers.expandHome(trimmedRootPath), isDirectory: true)
      .standardizedFileURL
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let projectName = trimmedName.isEmpty ? rootURL.lastPathComponent : trimmedName

    if projects.contains(where: { $0.rootPath == rootURL.path }) {
      lastMessage = "\(projectName) is already registered."
      return
    }

    projects.append(ProjectTarget(name: projectName, rootPath: rootURL.path))
    projects.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    saveProjects()
    lastMessage = "Added project \(projectName)."
  }

  public func removeProject(id: String) {
    guard let project = projects.first(where: { $0.id == id }) else {
      return
    }

    projects.removeAll { $0.id == id }
    saveProjects()
    lastMessage = "Removed project \(project.name)."
  }

  public func status(skill: SkillInfo, tool: AgentTool) -> SkillLinkStatus {
    linkService.status(skill: skill, in: tool, fileManager: fileManager)
  }

  public func status(skill: SkillInfo, project: ProjectTarget) -> SkillLinkStatus {
    linkService.status(skill: skill, in: project, fileManager: fileManager)
  }

  public func isDirectoryPresent(for tool: AgentTool) -> Bool {
    isDirectoryPresent(at: tool.skillsDirectoryURL)
  }

  public func isDirectoryPresent(for project: ProjectTarget) -> Bool {
    isDirectoryPresent(at: project.skillsDirectoryURL)
  }

  public func isProjectRootPresent(for project: ProjectTarget) -> Bool {
    isDirectoryPresent(at: project.rootURL)
  }

  private func isDirectoryPresent(at url: URL) -> Bool {
    var isDirectory: ObjCBool = false
    return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
  }

  public func install(skill: SkillInfo, into tool: AgentTool) {
    do {
      let result = try linkService.install(skill: skill, into: tool, fileManager: fileManager)
      lastMessage = "\(result.title): \(result.detail)"
    } catch {
      lastMessage = error.localizedDescription
    }
  }

  public func uninstall(skill: SkillInfo, from tool: AgentTool) {
    do {
      let result = try linkService.uninstall(skill: skill, from: tool, fileManager: fileManager)
      lastMessage = "\(result.title): \(result.detail)"
    } catch {
      lastMessage = error.localizedDescription
    }
  }

  public func install(skill: SkillInfo, into project: ProjectTarget) {
    do {
      let result = try linkService.install(skill: skill, into: project, fileManager: fileManager)
      lastMessage = "\(result.title): \(result.detail)"
    } catch {
      lastMessage = error.localizedDescription
    }
  }

  public func uninstall(skill: SkillInfo, from project: ProjectTarget) {
    do {
      let result = try linkService.uninstall(skill: skill, from: project, fileManager: fileManager)
      lastMessage = "\(result.title): \(result.detail)"
    } catch {
      lastMessage = error.localizedDescription
    }
  }

  public func installedTools(for skill: SkillInfo) -> [AgentTool] {
    tools.filter { status(skill: skill, tool: $0).isInstalled }
  }

  public func installedProjects(for skill: SkillInfo) -> [ProjectTarget] {
    projects.filter { status(skill: skill, project: $0).isInstalled }
  }

  public func installedSkills(for tool: AgentTool) -> [SkillInfo] {
    skills.filter { status(skill: $0, tool: tool).isInstalled }
  }

  public func installedSkills(for project: ProjectTarget) -> [SkillInfo] {
    skills.filter { status(skill: $0, project: project).isInstalled }
  }

  public func conflicts(for tool: AgentTool) -> Int {
    skills.reduce(0) { count, skill in
      if case .conflict = status(skill: skill, tool: tool) {
        return count + 1
      }

      return count
    }
  }

  public func conflicts(for project: ProjectTarget) -> Int {
    skills.reduce(0) { count, skill in
      if case .conflict = status(skill: skill, project: project) {
        return count + 1
      }

      return count
    }
  }

  private func refreshTools() {
    tools = ToolCatalog.knownTools(fileManager: fileManager) + customTools
  }

  private func saveCustomTools() {
    if let data = try? JSONEncoder().encode(customTools) {
      defaults.set(data, forKey: customToolsKey)
    }
  }

  private func saveProjects() {
    if let data = try? JSONEncoder().encode(projects) {
      defaults.set(data, forKey: projectsKey)
    }
  }

  private static func loadCustomTools(defaults: UserDefaults, key: String) -> [AgentTool] {
    guard let data = defaults.data(forKey: key) else {
      return []
    }

    return (try? JSONDecoder().decode([AgentTool].self, from: data)) ?? []
  }

  private static func loadProjects(defaults: UserDefaults, key: String) -> [ProjectTarget] {
    guard let data = defaults.data(forKey: key) else {
      return []
    }

    return (try? JSONDecoder().decode([ProjectTarget].self, from: data)) ?? []
  }
}
