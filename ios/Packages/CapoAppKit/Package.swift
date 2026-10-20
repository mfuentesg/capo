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
    .package(path: "../CapoUI"),
    .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0")
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
        .product(name: "CapoCore", package: "CapoCore"),
        .product(name: "Supabase", package: "supabase-swift")
      ],
      swiftSettings: [.defaultIsolation(MainActor.self)]
    ),
    .testTarget(
      name: "CapoAppKitTests",
      dependencies: [
        "CapoAppKit",
        .product(name: "CapoFakes", package: "CapoCore"),
        .product(name: "CapoSupabase", package: "CapoSupabase"),
        .product(name: "Supabase", package: "supabase-swift")
      ]
    )
  ],
  swiftLanguageModes: [.v6]
)
