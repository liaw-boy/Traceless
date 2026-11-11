// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "AppSweep",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AppSweep", targets: ["AppSweep"]),
        .library(name: "AppSweepCore", targets: ["AppSweepCore"])
    ],
    targets: [
        .target(
            name: "AppSweepCore",
            path: "Sources/AppSweepCore"
        ),
        .executableTarget(
            name: "AppSweep",
            dependencies: ["AppSweepCore"],
            path: "Sources/AppSweep"
        ),
        .testTarget(
            name: "AppSweepCoreTests",
            dependencies: ["AppSweepCore"],
            path: "Tests/AppSweepCoreTests"
        )
    ]
)
