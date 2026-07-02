// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "KHInsiderPlayerMac",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "KHPlayer", targets: ["KHPlayer"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.3"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.9.6"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.11.1")
    ],
    targets: [
        .executableTarget(
            name: "KHPlayer",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
                "SwiftSoup",
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "Sources/KHPlayer",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "KHPlayerTests",
            dependencies: ["KHPlayer"],
            path: "Tests/KHPlayerTests",
            resources: [
                .process("Fixtures")
            ]
        )
    ]
)
