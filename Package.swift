// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CopyTranslate",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "CopyTranslate", targets: ["CopyTranslate"]),
    ],
    targets: [
        .executableTarget(
            name: "CopyTranslate",
            dependencies: ["CopyTranslateCore"],
            path: "Sources/CopyTranslate"
        ),
        // Pure, dependency-free logic (env parsing, prompt building, cache keys,
        // double-tap timing, SSE parsing, language list). Unit-tested.
        .target(
            name: "CopyTranslateCore",
            path: "Sources/CopyTranslateCore"
        ),
        .testTarget(
            name: "CopyTranslateCoreTests",
            dependencies: ["CopyTranslateCore"],
            path: "Tests/CopyTranslateCoreTests"
        ),
    ]
)
