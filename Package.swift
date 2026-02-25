// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenLocalKeys",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "OpenLocalKeys", targets: ["OpenLocalKeys"])
    ],
    targets: [
        .executableTarget(
            name: "OpenLocalKeys",
            path: "src",
            sources: [
                "OpenLocalKeysApp.swift",
                "ContentView.swift"
            ]
        )
    ]
)
