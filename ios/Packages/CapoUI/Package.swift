// swift-tools-version: 6.2
import PackageDescription

let mainActorByDefault: [SwiftSetting] = [.defaultIsolation(MainActor.self)]

let package = Package(
  name: "CapoUI",
  defaultLocalization: "en",
  platforms: [.iOS(.v17)],
  products: [
    .library(name: "CapoDesign", targets: ["CapoDesign"]),
    .library(name: "CapoRendering", targets: ["CapoRendering"]),
    .library(name: "CapoAuthUI", targets: ["CapoAuthUI"]),
    .library(name: "CapoLibraryUI", targets: ["CapoLibraryUI"]),
    .library(name: "CapoPerformanceUI", targets: ["CapoPerformanceUI"]),
    .library(name: "CapoPlaylistsUI", targets: ["CapoPlaylistsUI"]),
    .library(name: "CapoEditorUI", targets: ["CapoEditorUI"]),
    .library(name: "CapoTeamsUI", targets: ["CapoTeamsUI"]),
    .library(name: "CapoSettingsUI", targets: ["CapoSettingsUI"]),
    .library(name: "CapoShellUI", targets: ["CapoShellUI"])
  ],
  dependencies: [
    .package(path: "../CapoCore")
  ],
  targets: [
    .target(
      name: "CapoDesign",
      dependencies: [
        .product(name: "CapoCore", package: "CapoCore"),
        .product(name: "CapoChordPro", package: "CapoCore"),
        .product(name: "CapoFakes", package: "CapoCore")
      ],
      resources: [.process("Resources")],
      swiftSettings: mainActorByDefault
    ),
    .target(
      name: "CapoRendering",
      dependencies: ["CapoDesign", .product(name: "CapoChordPro", package: "CapoCore")],
      resources: [.process("Resources")],
      swiftSettings: mainActorByDefault
    ),
    .target(name: "CapoAuthUI", dependencies: ["CapoDesign"], swiftSettings: mainActorByDefault),
    .target(name: "CapoLibraryUI", dependencies: ["CapoDesign"], swiftSettings: mainActorByDefault),
    .target(
      name: "CapoPerformanceUI",
      dependencies: ["CapoDesign", "CapoRendering"],
      swiftSettings: mainActorByDefault
    ),
    .target(
      name: "CapoPlaylistsUI",
      dependencies: ["CapoDesign", "CapoPerformanceUI", "CapoLibraryUI"],
      swiftSettings: mainActorByDefault
    ),
    .target(
      name: "CapoEditorUI",
      dependencies: ["CapoDesign", "CapoRendering"],
      swiftSettings: mainActorByDefault
    ),
    .target(name: "CapoTeamsUI", dependencies: ["CapoDesign"], swiftSettings: mainActorByDefault),
    .target(name: "CapoSettingsUI", dependencies: ["CapoDesign"], swiftSettings: mainActorByDefault),
    .target(
      name: "CapoShellUI",
      dependencies: [
        "CapoDesign", "CapoRendering", "CapoAuthUI", "CapoLibraryUI", "CapoPerformanceUI",
        "CapoPlaylistsUI", "CapoEditorUI", "CapoTeamsUI", "CapoSettingsUI"
      ],
      swiftSettings: mainActorByDefault
    ),
    .testTarget(name: "CapoDesignTests", dependencies: ["CapoDesign"]),
    .testTarget(name: "CapoAuthUITests", dependencies: ["CapoAuthUI"]),
    .testTarget(name: "CapoShellUITests", dependencies: ["CapoShellUI"]),
    .testTarget(name: "CapoRenderingTests", dependencies: ["CapoRendering"]),
    .testTarget(name: "CapoLibraryUITests", dependencies: ["CapoLibraryUI"]),
    .testTarget(name: "CapoPerformanceUITests", dependencies: ["CapoPerformanceUI"]),
    .testTarget(name: "CapoPlaylistsUITests", dependencies: ["CapoPlaylistsUI"]),
    .testTarget(name: "CapoEditorUITests", dependencies: ["CapoEditorUI"]),
    .testTarget(name: "CapoTeamsUITests", dependencies: ["CapoTeamsUI", "CapoDesign"])
  ],
  swiftLanguageModes: [.v6]
)
