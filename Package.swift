// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Uproot",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Uproot", targets: ["Uproot"]),
        .library(name: "UprootCore", targets: ["UprootCore"])
    ],
    targets: [
        .target(
            name: "UprootCore",
            path: "Sources/UprootCore"
        ),
        .executableTarget(
            name: "Uproot",
            dependencies: ["UprootCore"],
            path: "Sources/Uproot"
        ),
        .testTarget(
            name: "UprootCoreTests",
            dependencies: ["UprootCore"],
            path: "Tests/UprootCoreTests"
        )
    ]
)
