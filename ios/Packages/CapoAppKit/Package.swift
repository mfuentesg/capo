// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "CapoAppKit",
  platforms: [.iOS(.v17)],
  products: [
    .library(name: "CapoAppKit", targets: ["CapoAppKit"])
  ],
  dependencies: [
    .package(path: "../CapoCore"),
    .package(path: "../CapoData"),
    .package(path: "../CapoSupabase"),
    .package(path: "../CapoUI")
  ],
  targets: [
    .target(
      name: "CapoAppKit",
      dependencies: [
        .product(name: "CapoShellUI", package: "CapoUI"),
        .product(name: "CapoStore", package: "CapoData"),
        .product(name: "CapoSync", package: "CapoData"),
        .product(name: "CapoSupabase", package: "CapoSupabase"),
        .product(name: "CapoFakes", package: "CapoCore"),
        .product(name: "CapoCore", package: "CapoCore")
      ],
      swiftSettings: [.defaultIsolation(MainActor.self)]
    )
  ],
  swiftLanguageModes: [.v6]
)
