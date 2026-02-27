#!/usr/bin/env swift

import Foundation

/// A simple Unix socket client for testing the server

// Check if message argument is provided
guard CommandLine.arguments.count > 1 else {
    print("Usage: Client.swift <message>")
    print("Example: ./Client.swift 'Hello, Server!'")
    exit(1)
}

let message = CommandLine.arguments[1]
let socketPath = "/tmp/example.sock"

print("🔌 Connecting to \(socketPath)...")

// Create socket
let clientSocket = socket(AF_UNIX, SOCK_STREAM, 0)
guard clientSocket != -1 else {
    print("❌ Failed to create socket")
    exit(1)
}

// Set up socket address
var addr = sockaddr_un()
addr.sun_family = sa_family_t(AF_UNIX)
socketPath.withCString { path in
    strncpy(&addr.sun_path.0, path, MemoryLayout.size(ofValue: addr.sun_path) - 1)
}

// Connect to server
let connectResult = withUnsafePointer(to: &addr) {
    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        connect(clientSocket, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
    }
}

guard connectResult == 0 else {
    print("❌ Failed to connect: \(errno)")
    close(clientSocket)
    exit(1)
}

print("✅ Connected")
print("📤 Sending: \(message)")

// Send message
let messageToSend = message + "\n"
let bytesWritten = messageToSend.withCString { bytes in
    write(clientSocket, bytes, messageToSend.count)
}

guard bytesWritten > 0 else {
    print("❌ Failed to send message")
    close(clientSocket)
    exit(1)
}

// Read response
var buffer = [UInt8](repeating: 0, count: 4096)
let bytesRead = read(clientSocket, &buffer, buffer.count)

if bytesRead > 0 {
    let response = String(bytes: buffer[0..<bytesRead], encoding: .utf8)?.trimmingCharacters(in: .newlines)
    print("📥 Received: \(response ?? "(invalid)")")
} else {
    print("❌ No response from server")
}

close(clientSocket)
print("👋 Connection closed")
