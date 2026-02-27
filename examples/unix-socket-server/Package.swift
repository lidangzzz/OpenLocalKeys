// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "UnixSocketServerExample",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "UnixSocketServerExample",
            path: ".",
            exclude: [
                "Client.swift",
                "README.md"
            ],
            sources: [
                "main.swift",
                "SimpleSocketServer.swift"
            ]
        )
    ]
)
