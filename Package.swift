// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenLocalKeys",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "OpenLocalKeys", targets: ["OpenLocalKeysHTTP"])
    ],
    dependencies: [],
    targets: [
        // OpenLocalKeys App (HTTP) with embedded HTTPServer
        .executableTarget(
            name: "OpenLocalKeysHTTP",
            dependencies: [],
            path: "src-http",
            exclude: [
                "Views/KeyRequestDialog.swift",  // Unix socket version, uses SocketServer
                "example.html",                // Test file
                "README.md",                   // Documentation
                "sdk-http.js"                  // JavaScript SDK
            ],
            sources: [
                "OpenLocalKeysHTTPApp.swift",
                "HTTPKeyRequestDialog.swift",
                "ContentView.swift",
                "Models/ApiKeyItem.swift",
                "Models/Provider.swift",
                "ViewModels/KeyManagerViewModel.swift",
                "Views/ItemEditView.swift",
                "HTTPServer/HTTPServer.swift",
                "HTTPServer/HTTPModels.swift"
            ]
        )
    ]
)
