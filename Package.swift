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
    targets: [
        .target(
            name: "TracelessCore",
            path: "Sources/TracelessCore"
        ),
        .executableTarget(
            name: "Traceless",
            dependencies: ["TracelessCore"],
            path: "Sources/Traceless"
        ),
        .testTarget(
            name: "TracelessCoreTests",
            dependencies: ["TracelessCore"],
            path: "Tests/TracelessCoreTests"
        )
    ]
)
