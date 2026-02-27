import Foundation

/// A simple Unix socket server example
/// This demonstrates how to create a basic Unix domain socket server in Swift

let server = SimpleSocketServer()

// Handle Ctrl+C to gracefully shutdown
let signalSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
signalSource.setEventHandler {
    print("\n👋 Shutting down...")
    server.stop()
    exit(0)
}
signalSource.resume()

// Start the server
print("==========================================")
print("   Unix Socket Server Example")
print("==========================================")
print()

server.start { message in
    print("💬 Processing message: \(message)")
}

print()
print("Server is running! Press Ctrl+C to stop.")
print("To test the server, run in another terminal:")
print("  echo 'Hello' | nc -U \(server.path)")
print()

// Run the main loop
RunLoop.main.run()
