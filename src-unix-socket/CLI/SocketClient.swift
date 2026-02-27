import Foundation
import SocketServer

/// A client for connecting to the OpenLocalKeys socket server
public struct SocketClient {
    let socketPath: String

    public init(socketPath: String? = nil) {
        if let path = socketPath {
            self.socketPath = path
        } else {
            // Use the default socket path
            let tempDir = NSTemporaryDirectory()
            self.socketPath = tempDir.hasSuffix("/")
                ? "\(tempDir)com.openlocalkeys.sock"
                : "\(tempDir)/com.openlocalkeys.sock"
        }
    }

    /// Connect to the socket server and request API keys
    /// - Returns: Array of SocketApiKey if successful, nil otherwise
    public func requestKeys() throws -> [SocketApiKey] {
        let clientSocket = socket(AF_UNIX, SOCK_STREAM, 0)
        guard clientSocket != -1 else {
            throw SocketClientError.socketCreationFailed
        }

        defer {
            close(clientSocket)
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
            let error = NSError(domain: "SocketClient", code: Int(errno), userInfo: [
                NSLocalizedDescriptionKey: "Failed to connect to socket server at \(socketPath)"
            ])
            throw SocketClientError.connectionFailed(error)
        }

        // Send request
        let request = "REQUEST_KEYS"
        guard request.withCString({ bytes in
            write(clientSocket, bytes, request.count)
        }) > 0 else {
            throw SocketClientError.writeFailed
        }

        // Read response
        let response = try readResponse(from: clientSocket)

        // Parse JSON response
        let decoder = JSONDecoder()
        let keys = try decoder.decode([SocketApiKey].self, from: response)

        return keys
    }

    /// Read response from socket
    private func readResponse(from socket: Int32) throws -> Data {
        var buffer = [UInt8](repeating: 0, count: 8192)
        let bytesRead = read(socket, &buffer, buffer.count)

        guard bytesRead > 0 else {
            throw SocketClientError.readFailed
        }

        return Data(bytes: buffer, count: bytesRead)
    }

    /// Check if the socket server is running
    public func isServerRunning() -> Bool {
        guard FileManager.default.fileExists(atPath: socketPath) else {
            return false
        }

        let clientSocket = socket(AF_UNIX, SOCK_STREAM, 0)
        guard clientSocket != -1 else {
            return false
        }

        defer {
            close(clientSocket)
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        socketPath.withCString { path in
            strncpy(&addr.sun_path.0, path, MemoryLayout.size(ofValue: addr.sun_path) - 1)
        }

        let connectResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(clientSocket, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        return connectResult == 0
    }
}

/// Errors that can occur during socket operations
public enum SocketClientError: Error, LocalizedError {
    case socketCreationFailed
    case connectionFailed(Error)
    case writeFailed
    case readFailed
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .socketCreationFailed:
            return "Failed to create socket"
        case .connectionFailed(let error):
            return "Failed to connect to server: \(error.localizedDescription)"
        case .writeFailed:
            return "Failed to write to socket"
        case .readFailed:
            return "Failed to read from socket"
        case .invalidResponse:
            return "Invalid response from server"
        }
    }
}
