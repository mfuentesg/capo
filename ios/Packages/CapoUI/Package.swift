// swift-tools-version: 6.2
import PackageDescription

let mainActorByDefault: [SwiftSetting] = [.defaultIsolation(MainActor.self)]

let package = Package(
  name: "CapoUI",
  defaultLocalization: "en",
  platforms: [.iOS(.v17)],
  products: [
    .library(name: "CapoDesign", targets: ["CapoDesign"]),
    .library(name: "CapoIcons", targets: ["CapoIcons"]),
    .library(name: "CapoRendering", targets: ["CapoRendering"]),
    .library(name: "CapoAuthUI", targets: ["CapoAuthUI"]),
    .library(name: "CapoLibraryUI", targets: ["CapoLibraryUI"]),
    .library(name: "CapoPerformanceUI", targets: ["CapoPerformanceUI"]),
    .library(name: "CapoPlaylistsUI", targets: ["CapoPlaylistsUI"]),
    .library(name: "CapoEditorUI", targets: ["CapoEditorUI"]),
    .library(name: "CapoChordsUI", targets: ["CapoChordsUI"]),
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
        "CapoIcons",
        .product(name: "CapoCore", package: "CapoCore"),
        .product(name: "CapoChordPro", package: "CapoCore"),
        .product(name: "CapoFakes", package: "CapoCore")
      ],
      resources: [.process("Resources")],
      swiftSettings: mainActorByDefault
    ),
    .target(name: "CapoIcons", swiftSettings: mainActorByDefault),
    .target(
      name: "CapoRendering",
      dependencies: [
        "CapoDesign", .product(name: "CapoChordPro", package: "CapoCore"),
        .product(name: "CapoCore", package: "CapoCore")
      ],
      resources: [.process("Resources")],
      swiftSettings: mainActorByDefault
    ),
    .target(name: "CapoAuthUI", dependencies: ["CapoDesign"], swiftSettings: mainActorByDefault),
    .target(name: "CapoLibraryUI", dependencies: ["CapoDesign", "CapoIcons"], swiftSettings: mainActorByDefault),
    .target(
      name: "CapoPerformanceUI",
      dependencies: ["CapoDesign", "CapoIcons", "CapoRendering"],
      swiftSettings: mainActorByDefault
    ),
    .target(
      name: "CapoPlaylistsUI",
      dependencies: ["CapoDesign", "CapoIcons", "CapoPerformanceUI", "CapoLibraryUI"],
      swiftSettings: mainActorByDefault
    ),
    .target(
      name: "CapoEditorUI",
      dependencies: [
        "CapoDesign", "CapoRendering", "CapoIcons",
        .product(name: "CapoChordPro", package: "CapoCore")
      ],
      swiftSettings: mainActorByDefault
    ),
    .target(
      name: "CapoChordsUI",
      dependencies: ["CapoDesign", "CapoIcons", "CapoRendering"],
      swiftSettings: mainActorByDefault
    ),
    .target(
      name: "CapoTeamsUI", dependencies: ["CapoDesign", "CapoIcons"], swiftSettings: mainActorByDefault
    ),
    .target(name: "CapoSettingsUI", dependencies: ["CapoDesign", "CapoIcons"], swiftSettings: mainActorByDefault),
    .target(
      name: "CapoShellUI",
      dependencies: [
        "CapoDesign", "CapoIcons", "CapoRendering", "CapoAuthUI", "CapoLibraryUI", "CapoPerformanceUI",
        "CapoPlaylistsUI", "CapoEditorUI", "CapoChordsUI", "CapoTeamsUI", "CapoSettingsUI"
      ],
      swiftSettings: mainActorByDefault
    ),
    .testTarget(name: "CapoDesignTests", dependencies: ["CapoDesign"]),
    .testTarget(name: "CapoIconsTests", dependencies: ["CapoIcons"]),
    .testTarget(name: "CapoAuthUITests", dependencies: ["CapoAuthUI"]),
    .testTarget(name: "CapoShellUITests", dependencies: ["CapoShellUI"]),
    .testTarget(name: "CapoRenderingTests", dependencies: ["CapoRendering"]),
    .testTarget(name: "CapoLibraryUITests", dependencies: ["CapoLibraryUI"]),
    .testTarget(name: "CapoPerformanceUITests", dependencies: ["CapoPerformanceUI"]),
    .testTarget(name: "CapoPlaylistsUITests", dependencies: ["CapoPlaylistsUI"]),
    .testTarget(name: "CapoEditorUITests", dependencies: ["CapoEditorUI"]),
    .testTarget(name: "CapoChordsUITests", dependencies: ["CapoChordsUI", "CapoRendering"]),
    .testTarget(name: "CapoTeamsUITests", dependencies: ["CapoTeamsUI", "CapoDesign", "CapoIcons"])
  ],
  swiftLanguageModes: [.v6]
)
