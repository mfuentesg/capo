// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "CapoSupabase",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [
    .library(name: "CapoSupabase", targets: ["CapoSupabase"])
  ],
  dependencies: [
    .package(path: "../CapoCore"),
    .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0")
  ],
  targets: [
    .target(
      name: "CapoSupabase",
      dependencies: [
        .product(name: "CapoCore", package: "CapoCore"),
        .product(name: "Supabase", package: "supabase-swift")
      ]
    ),
    .testTarget(
      name: "CapoSupabaseTests",
      dependencies: ["CapoSupabase"],
      resources: [.copy("Fixtures")]
    )
  ],
  swiftLanguageModes: [.v6]
)
