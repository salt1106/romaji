// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Romaji",
    platforms: [
        .macOS(.v26)
    ],
    targets: [
        .executableTarget(
            name: "Romaji",
            path: "Sources/Romaji"
        )
    ]
)
