// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Traceless",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Traceless", targets: ["Traceless"]),
        .library(name: "TracelessCore", targets: ["TracelessCore"])
    ],
    dependencies: [
        // Auto-update; pinned so a release never picks up an unreviewed version.
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")
    ],
    targets: [
        .target(
            name: "TracelessCore",
            path: "Sources/TracelessCore"
        ),
        .executableTarget(
            name: "Traceless",
            dependencies: ["TracelessCore", .product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/Traceless"
        ),
        .testTarget(
            name: "TracelessCoreTests",
            dependencies: ["TracelessCore"],
            path: "Tests/TracelessCoreTests"
        )
    ]
)
