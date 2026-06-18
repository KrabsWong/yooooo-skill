// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "YoooooSkillManager",
  platforms: [
    .macOS(.v26)
  ],
  products: [
    .library(
      name: "YoooooSkillManagerCore",
      targets: ["YoooooSkillManagerCore"]
    ),
    .executable(
      name: "YoooooSkillManager",
      targets: ["YoooooSkillManager"]
    )
  ],
  targets: [
    .target(name: "YoooooSkillManagerCore"),
    .executableTarget(
      name: "YoooooSkillManager",
      dependencies: ["YoooooSkillManagerCore"],
      resources: [.process("Resources")]
    ),
    .testTarget(
      name: "YoooooSkillManagerCoreTests",
      dependencies: ["YoooooSkillManagerCore"]
    )
  ],
  swiftLanguageModes: [.v6]
)
