// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ProjectManagerCore",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ProjectManagerCore",
            targets: ["ProjectManagerCore"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ProjectManagerCore",
            dependencies: [],
            path: "Sources/ProjectManagerCore"
        ),
        .testTarget(
            name: "ProjectManagerCoreTests",
            dependencies: ["ProjectManagerCore"],
            path: "Tests"
        ),
    ]
)