// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ButtercupKit",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "ButtercupKit", targets: ["ButtercupKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift", from: "2.55.0")
    ],
    targets: [
        .target(
            name: "ButtercupKit",
            dependencies: [.product(name: "Supabase", package: "supabase-swift")]
        )
    ]
)
