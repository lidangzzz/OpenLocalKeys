import Foundation
import SocketServer

// MARK: - Main Entry Point

let arguments = CommandLine.arguments

// Check for help flag
if arguments.contains("--help") || arguments.contains("-h") {
    printUsage()
    exit(0)
}

// Check for status flag
if arguments.contains("--status") || arguments.contains("-s") {
    checkStatus()
    exit(0)
}

// Check for path flag
var socketPath: String?
if let pathIndex = arguments.firstIndex(of: "--path"), pathIndex + 1 < arguments.count {
    socketPath = arguments[pathIndex + 1]
} else if let pathIndex = arguments.firstIndex(of: "-p"), pathIndex + 1 < arguments.count {
    socketPath = arguments[pathIndex + 1]
}

// Default action: request keys
do {
    let client = SocketClient(socketPath: socketPath)

    // Check if server is running
    if !client.isServerRunning() {
        print("❌ Error: OpenLocalKeys server is not running")
        print("   Please start the OpenLocalKeys app first")
        exit(1)
    }

    print("🔑 Requesting API keys from OpenLocalKeys...")
    print("   Please approve the request in the popup dialog...")

    let keys = try client.requestKeys()

    if keys.isEmpty {
        print("\n⚠️  No keys returned (request was denied or no keys available)")
        exit(0)
    }

    print("\n✅ Received \(keys.count) API key(s):\n")

    for (index, key) in keys.enumerated() {
        print("   [\(index + 1)] \(key.displayName)")
        print("       Provider: \(key.provider)")
        print("       Key: \(maskKey(key.privateKey))")

        if let customName = key.customProviderName {
            print("       Custom Provider: \(customName)")
        }
        if let customURL = key.customProviderURL {
            print("       API URL: \(customURL)")
        }

        print()
    }

    // Output as JSON if --json flag is provided
    if arguments.contains("--json") || arguments.contains("-j") {
        outputJSON(keys)
    }

} catch {
    print("❌ Error: \(error.localizedDescription)")
    exit(1)
}

// MARK: - Helper Functions

func printUsage() {
    print("""
    OLKeys - OpenLocalKeys Command Line Client

    USAGE:
        olkeys [OPTIONS]

    OPTIONS:
        -h, --help          Show this help message
        -s, --status        Check if OpenLocalKeys server is running
        -p, --path <path>   Custom socket path (default: /tmp/com.openlocalkeys.sock)
        -j, --json          Output results as JSON

    EXAMPLES:
        olkeys                           # Request API keys (default)
        olkeys --status                   # Check server status
        olkeys --json                     # Get keys as JSON
        olkeys --path /tmp/mysock.sock    # Use custom socket path

    The OpenLocalKeys app must be running for this client to work.
    """)
}

func checkStatus() {
    let client = SocketClient()

    if client.isServerRunning() {
        print("✅ OpenLocalKeys server is running")
        print("   Socket: \(client.socketPath)")
    } else {
        print("❌ OpenLocalKeys server is not running")
        print("   Please start the OpenLocalKeys app")
        exit(1)
    }
}

func maskKey(_ key: String) -> String {
    if key.count <= 8 {
        return String(repeating: "*", count: key.count)
    }

    let prefix = String(key.prefix(4))
    let suffix = String(key.suffix(4))
    return "\(prefix)***\(suffix)"
}

func outputJSON(_ keys: [SocketApiKey]) {
    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(keys)
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print("\n--- JSON OUTPUT ---")
            print(jsonString)
        }
    } catch {
        print("⚠️  Failed to output JSON: \(error.localizedDescription)")
    }
}
