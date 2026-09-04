// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClaudeUsageBar",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "ClaudeUsageCore",
            path: "Sources/ClaudeUsageCore"
        ),
        .executableTarget(
            name: "ClaudeUsageBar",
            dependencies: ["ClaudeUsageCore"],
            path: "Sources/ClaudeUsageBar",
            resources: [.copy("Resources/logo-white.png")]
        ),
        .testTarget(
            name: "ClaudeUsageBarTests",
            dependencies: ["ClaudeUsageCore"],
            path: "Tests/ClaudeUsageBarTests"
        ),
    ],
    swiftLanguageVersions: [.v5]
)
