import Foundation

// MARK: - Request Models

/// Represents an API key that can be sent to clients
public struct SocketApiKey: Codable, Sendable {
    public let displayName: String
    public let privateKey: String
    public let provider: String
    public let customProviderName: String?
    public let customProviderURL: String?

    public init(
        displayName: String,
        privateKey: String,
        provider: String,
        customProviderName: String? = nil,
        customProviderURL: String? = nil
    ) {
        self.displayName = displayName
        self.privateKey = privateKey
        self.provider = provider
        self.customProviderName = customProviderName
        self.customProviderURL = customProviderURL
    }
}

/// Represents an incoming socket request
public final class SocketRequest: Identifiable, @unchecked Sendable {
    public let id: UUID
    public let clientPid: pid_t
    public let clientName: String
    public let socketFd: Int32
    private let closeCallback: @Sendable () -> Void
    public let callback: @Sendable ([SocketApiKey]) -> Void

    public init(
        clientPid: pid_t,
        clientName: String,
        socketFd: Int32,
        closeCallback: @escaping @Sendable () -> Void,
        callback: @escaping @Sendable ([SocketApiKey]) -> Void
    ) {
        self.id = UUID()
        self.clientPid = clientPid
        self.clientName = clientName
        self.socketFd = socketFd
        self.closeCallback = closeCallback
        self.callback = callback
    }

    /// Close the socket connection manually.
    /// This should be called after the callback is invoked.
    public func closeSocket() {
        closeCallback()
    }
}

// MARK: - Errors

public enum SocketServerError: Error, LocalizedError {
    case socketCreationFailed
    case socketBindFailed(Error)
    case socketListenFailed(Error)
    case acceptFailed
    case readFailed(Error)
    case writeFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .socketCreationFailed:
            return "Failed to create socket"
        case .socketBindFailed(let error):
            return "Failed to bind socket: \(error.localizedDescription)"
        case .socketListenFailed(let error):
            return "Failed to listen on socket: \(error.localizedDescription)"
        case .acceptFailed:
            return "Failed to accept connection"
        case .readFailed(let error):
            return "Failed to read from socket: \(error.localizedDescription)"
        case .writeFailed(let error):
            return "Failed to write to socket: \(error.localizedDescription)"
        }
    }
}
