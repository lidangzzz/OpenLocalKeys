// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenLocalKeys",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "SocketServer", targets: ["SocketServer"]),
        .executable(name: "OpenLocalKeys", targets: ["OpenLocalKeys"]),
        .executable(name: "olkeys", targets: ["OLKeysClient"])
    ],
    dependencies: [],
    targets: [
        // SocketServer Library
        .target(
            name: "SocketServer",
            path: "SocketServer",
            sources: [
                "SocketServer.swift",
                "SocketModels.swift"
            ]
        ),
        .testTarget(
            name: "SocketServerTests",
            dependencies: ["SocketServer"],
            path: "SocketServerTests"
        ),

        // OpenLocalKeys App
        .executableTarget(
            name: "OpenLocalKeys",
            dependencies: ["SocketServer"],
            path: "src",
            sources: [
                "OpenLocalKeysApp.swift",
                "ContentView.swift",
                "Models/ApiKeyItem.swift",
                "Models/Provider.swift",
                "ViewModels/KeyManagerViewModel.swift",
                "Views/ItemEditView.swift",
                "Views/KeyRequestDialog.swift"
            ]
        ),

        // OLKeys CLI Client
        .executableTarget(
            name: "OLKeysClient",
            dependencies: ["SocketServer"],
            path: "CLI",
            sources: [
                "main.swift",
                "SocketClient.swift"
            ]
        ),
        .testTarget(
            name: "OLKeysClientTests",
            dependencies: ["OLKeysClient"],
            path: "CLITests"
        )
    ]
)
