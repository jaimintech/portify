// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Portify",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        // Shared core library (scanner, models, protocols)
        .target(
            name: "PortifyCore",
            path: "Portify/Core"
        ),

        // Main GUI app
        .executableTarget(
            name: "Portify",
            dependencies: ["PortifyCore"],
            path: "Portify",
            exclude: ["Core"],
            resources: [
                .process("Resources")
            ]
        ),

        // CLI companion
        .executableTarget(
            name: "portify-cli",
            dependencies: [
                "PortifyCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "CLI"
        ),

        .testTarget(
            name: "PortifyTests",
            dependencies: ["Portify", "PortifyCore"],
            path: "PortifyTests"
        ),
    ]
)
