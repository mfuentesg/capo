// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "CapoCore",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [
    .library(name: "CapoCore", targets: ["CapoCore"]),
    .library(name: "CapoChordPro", targets: ["CapoChordPro"]),
    .library(name: "CapoFakes", targets: ["CapoFakes"])
  ],
  targets: [
    .target(name: "CapoCore"),
    .target(name: "CapoChordPro"),
    .target(name: "CapoFakes", dependencies: ["CapoCore", "CapoChordPro"]),
    .testTarget(name: "CapoCoreTests", dependencies: ["CapoCore", "CapoFakes"]),
    .testTarget(name: "CapoChordProTests", dependencies: ["CapoChordPro"])
  ],
  swiftLanguageModes: [.v6]
)
