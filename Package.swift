// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Portify",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Portify",
            path: "Portify",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PortifyTests",
            dependencies: ["Portify"],
            path: "PortifyTests"
        ),
    ]
)
