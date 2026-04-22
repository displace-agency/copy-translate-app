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
            path: "Sources/CopyTranslate"
        ),
    ]
)
