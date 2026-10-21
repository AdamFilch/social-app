// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ButtercupKit",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "ButtercupKit", targets: ["ButtercupKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift", from: "2.55.0"),
        .package(url: "https://github.com/livekit/client-sdk-swift", from: "2.18.0")
    ],
    targets: [
        .target(
            name: "ButtercupKit",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift"),
                .product(name: "LiveKit", package: "client-sdk-swift")
            ]
        )
    ]
)
