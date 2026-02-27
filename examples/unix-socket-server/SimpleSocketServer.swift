import Foundation

/// A simple Unix domain socket server example
/// This server listens for text messages and echoes them back with a timestamp
public class SimpleSocketServer {
    private var listenSocket: Int32 = -1
    private var runSource: DispatchSourceRead?
    private let socketPath: String
    private let queue = DispatchQueue(label: "com.example.socketserver")

    public init(socketPath: String) {
        self.socketPath = socketPath
    }

    /// Convenience initializer using temp directory
    public convenience init() {
        let tempDir = NSTemporaryDirectory()
        let socketPath = tempDir.hasSuffix("/")
            ? "\(tempDir)example.sock"
            : "\(tempDir)/example.sock"
        self.init(socketPath: socketPath)
    }

    deinit {
        stop()
    }

    /// Start the socket server
    /// - Parameter onMessage: Callback invoked when a message is received
    public func start(onMessage: @escaping (String) -> Void) {
        print("🔧 Starting Unix Socket Server...")
        print("📍 Socket path: \(socketPath)")

        // Remove existing socket file if it exists
        if FileManager.default.fileExists(atPath: socketPath) {
            try? FileManager.default.removeItem(atPath: socketPath)
            print("🗑️  Removed existing socket file")
        }

        // Validate socket path length
        guard socketPath.utf8.count < Int(PATH_MAX) - 1 else {
            print("❌ Socket path too long")
            return
        }

        // Create socket
        listenSocket = socket(AF_UNIX, SOCK_STREAM, 0)
        guard listenSocket != -1 else {
            print("❌ Failed to create socket: \(errno)")
            return
        }

        // Set socket options
        var value = 1
        setsockopt(listenSocket, SOL_SOCKET, SO_REUSEADDR, &value, socklen_t(MemoryLayout<Int>.size))

        // Bind to socket path
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        _ = socketPath.withCString { path in
            strncpy(&addr.sun_path.0, path, MemoryLayout.size(ofValue: addr.sun_path) - 1)
        }

        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(listenSocket, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard bindResult == 0 else {
            print("❌ Failed to bind socket: \(errno)")
            close(listenSocket)
            return
        }

        // Listen for connections
        let listenResult = listen(listenSocket, 5)
        guard listenResult == 0 else {
            print("❌ Failed to listen: \(errno)")
            close(listenSocket)
            return
        }

        print("✅ Server listening on socket")
        print("⏳ Waiting for connections...")

        // Set up dispatch source
        runSource = DispatchSource.makeReadSource(
            fileDescriptor: listenSocket,
            queue: queue
        )

        runSource?.setEventHandler { [weak self] in
            self?.handleNewConnection(onMessage: onMessage)
        }

        runSource?.setCancelHandler { [weak self] in
            guard let self = self else { return }
            print("🛑 Server stopped")
            close(self.listenSocket)
            try? FileManager.default.removeItem(atPath: self.socketPath)
        }

        runSource?.resume()
    }

    /// Stop the server
    public func stop() {
        print("🛑 Stopping server...")
        runSource?.cancel()
        runSource = nil
    }

    /// Check if server is running
    public var isRunning: Bool {
        return runSource != nil
    }

    /// Get the socket path
    public var path: String {
        return socketPath
    }

    // MARK: - Private Methods

    private func handleNewConnection(onMessage: @escaping (String) -> Void) {
        var clientAddr = sockaddr()
        var clientAddrLen = socklen_t(MemoryLayout<sockaddr>.size)

        let clientSocket = accept(listenSocket, &clientAddr, &clientAddrLen)
        guard clientSocket != -1 else {
            print("❌ Failed to accept connection")
            return
        }

        print("📥 New client connected")

        // Read message from client
        let message: String
        do {
            message = try readFromSocket(clientSocket)
        } catch {
            print("❌ Error reading from socket: \(error)")
            close(clientSocket)
            return
        }

        print("📨 Received: \(message)")

        // Notify on main thread
        DispatchQueue.main.async {
            onMessage(message)
        }

        // Send response back to client
        let response = "Echo: \(message) at \(Date())"
        sendResponse(socket: clientSocket, message: response)

        close(clientSocket)
        print("✅ Response sent, connection closed")
    }

    private func readFromSocket(_ socket: Int32) throws -> String {
        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = read(socket, &buffer, buffer.count)

        if bytesRead > 0 {
            let data = Data(bytes: buffer, count: bytesRead)
            guard let message = String(data: data, encoding: .utf8) else {
                throw SocketError.encodingFailed
            }
            return message.trimmingCharacters(in: .newlines)
        } else if bytesRead == 0 {
            throw SocketError.connectionClosed
        } else {
            let error = NSError(domain: "Socket", code: Int(errno))
            throw SocketError.readFailed(error)
        }
    }

    private func sendResponse(socket: Int32, message: String) {
        let message = message + "\n"
        let bytesWritten = message.withCString { bytes in
            write(socket, bytes, message.count)
        }

        if bytesWritten < 0 {
            print("❌ Failed to send response: \(errno)")
        } else {
            print("📤 Sent \(bytesWritten) bytes")
        }
    }
}

/// Socket errors
public enum SocketError: Error, LocalizedError {
    case readFailed(Error)
    case encodingFailed
    case connectionClosed

    public var errorDescription: String? {
        switch self {
        case .readFailed(let error):
            return "Read failed: \(error.localizedDescription)"
        case .encodingFailed:
            return "Failed to encode message"
        case .connectionClosed:
            return "Connection closed by client"
        }
    }
}
