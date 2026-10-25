// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "CapoData",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [
    .library(name: "CapoStore", targets: ["CapoStore"]),
    .library(name: "CapoSync", targets: ["CapoSync"])
  ],
  dependencies: [
    .package(path: "../CapoCore"),
    .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0")
  ],
  targets: [
    .target(
      name: "CapoStore",
      dependencies: [
        .product(name: "CapoCore", package: "CapoCore"),
        .product(name: "GRDB", package: "GRDB.swift")
      ]
    ),
    .target(
      name: "CapoSync",
      dependencies: ["CapoStore", .product(name: "CapoCore", package: "CapoCore")]
    ),
    .testTarget(
      name: "CapoStoreTests",
      dependencies: ["CapoStore", .product(name: "CapoFakes", package: "CapoCore")]
    ),
    .testTarget(
      name: "CapoSyncTests",
      dependencies: ["CapoSync", "CapoStore", .product(name: "CapoFakes", package: "CapoCore")]
    )
  ],
  swiftLanguageModes: [.v6]
)
