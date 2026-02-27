import Foundation

/// A Unix domain socket server that handles incoming API key requests
public final class SocketServer: NSObject, ObservableObject, @unchecked Sendable {
    /// Default socket path used by the server
    public static let defaultSocketPath = "/tmp/com.openlocalkeys.sock"

    private var listenSocket: Int32 = -1
    private var runSource: DispatchSourceRead?
    private let socketPath: String
    private var onIncomingRequest: ((SocketRequest) -> Void)?
    private let queue = DispatchQueue(label: "com.openlocalkeys.socketserver", attributes: .concurrent)

    public override init() {
        // Use /tmp for a consistent, predictable path that clients can find
        self.socketPath = Self.defaultSocketPath
        super.init()
    }

    /// Convenience initializer with custom socket path
    public init(socketPath: String) {
        self.socketPath = socketPath
        super.init()
    }

    deinit {
        stop()
    }

    // MARK: - Public Methods

    /// Start the socket server
    /// - Parameter onIncomingRequest: Callback invoked when a new request arrives
    public func start(onIncomingRequest: @escaping (SocketRequest) -> Void) {
        self.onIncomingRequest = onIncomingRequest

        // Remove existing socket file if it exists
        if FileManager.default.fileExists(atPath: socketPath) {
            try? FileManager.default.removeItem(atPath: socketPath)
        }

        // Validate socket path length
        guard socketPath.utf8.count < Int(PATH_MAX) - 1 else {
            print("SocketServer: Socket path too long: \(socketPath)")
            return
        }

        // Create socket
        listenSocket = socket(AF_UNIX, SOCK_STREAM, 0)
        guard listenSocket != -1 else {
            print("SocketServer: Failed to create socket")
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
            print("SocketServer: Failed to bind socket: \(errno)")
            close(listenSocket)
            return
        }

        // Listen for connections
        let listenResult = listen(listenSocket, 5)
        guard listenResult == 0 else {
            print("SocketServer: Failed to listen on socket: \(errno)")
            close(listenSocket)
            return
        }

        print("SocketServer: Listening at \(socketPath)")
        print("SocketServer: Socket path for clients: \(socketPath)")

        // Set up dispatch source for incoming connections
        runSource = DispatchSource.makeReadSource(
            fileDescriptor: listenSocket,
            queue: DispatchQueue.main
        )

        runSource?.setEventHandler { [weak self] in
            self?.handleNewConnection()
        }

        runSource?.setCancelHandler { [weak self] in
            guard let self = self else { return }
            print("SocketServer: Stopping server and cleaning up socket file")
            close(self.listenSocket)
            try? FileManager.default.removeItem(atPath: self.socketPath)
        }

        runSource?.resume()
    }

    /// Stop the socket server
    public func stop() {
        runSource?.cancel()
        runSource = nil
    }

    /// Restart the socket server
    /// - Parameter onIncomingRequest: Callback invoked when a new request arrives
    public func restart(onIncomingRequest: @escaping (SocketRequest) -> Void) {
        // Stop the current server
        stop()

        // Small delay to ensure clean shutdown
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            // Start the server again
            self.start(onIncomingRequest: onIncomingRequest)
            print("SocketServer: Restarted successfully")
        }
    }

    /// Get the socket path
    public var socketFilePath: String {
        return socketPath
    }

    /// Check if the server is running
    public var isRunning: Bool {
        return runSource != nil
    }

    // MARK: - Private Methods

    private func handleNewConnection() {
        do {
            var clientAddr = sockaddr()
            var clientAddrLen = socklen_t(MemoryLayout<sockaddr>.size)

            let clientSocket = accept(listenSocket, &clientAddr, &clientAddrLen)
            guard clientSocket != -1 else {
                print("SocketServer: Failed to accept connection")
                return
            }

            // Get peer credentials to identify the client
            var pid = pid_t(0)

            #if os(macOS)
            var pidSize = socklen_t(MemoryLayout<pid_t>.size)
            let credResult = getsockopt(
                clientSocket,
                SOL_LOCAL,
                LOCAL_PEERPID,
                &pid,
                &pidSize
            )
            #else
            let credResult = -1
            #endif

            // Get client app name (use 0 if getsockopt failed)
            let effectivePid = credResult == 0 ? pid : 0
            let clientName = getClientName(pid: effectivePid)

            // Read request from client
            let requestData: Data
            do {
                requestData = try readFromSocket(clientSocket)
            } catch {
                print("SocketServer: Error reading from socket: \(error)")
                close(clientSocket)
                return
            }

            guard let requestString = String(data: requestData, encoding: .utf8) else {
                print("SocketServer: Failed to decode request from client")
                close(clientSocket)
                return
            }

            print("SocketServer: Received request from \(clientName) (PID: \(effectivePid)): \(requestString)")

            // Handle request on main thread with UI callback
            // Capture clientSocket to prevent use-after-free
            let socketFd = clientSocket

            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    print("SocketServer: Warning - self is nil, closing socket")
                    close(socketFd)
                    return
                }

                // Create close callback that app can call manually
                let closeCallback: @Sendable () -> Void = { [socketFd] in
                    close(socketFd)
                }

                let request = SocketRequest(
                    clientPid: effectivePid,
                    clientName: clientName,
                    socketFd: socketFd,
                    closeCallback: closeCallback,
                    callback: { [weak self, socketFd] selectedItems in
                        // Create response data on main thread
                        guard let self = self else {
                            print("SocketServer: Warning - SocketServer was deallocated before callback, cannot send response")
                            close(socketFd)
                            return
                        }

                        let jsonData: Data
                        do {
                            jsonData = try self.createResponseData(items: selectedItems)
                        } catch {
                            print("SocketServer: Error creating response: \(error)")
                            // Send empty response on error
                            do {
                                jsonData = try JSONEncoder().encode([SocketApiKey]())
                            } catch {
                                print("SocketServer: Critical error - cannot create empty response")
                                close(socketFd)
                                return
                            }
                        }

                        // Send response synchronously - Unix domain socket writes are fast enough
                        do {
                            try self.sendResponseData(socket: socketFd, data: jsonData)
                        } catch {
                            print("SocketServer: Error sending response: \(error)")
                        }

                        // Note: Socket NOT closed here - app must call request.closeSocket()
                    }
                )

                // Notify the delegate
                self.onIncomingRequest?(request)
            }
        }
    }

    private func readFromSocket(_ socket: Int32) throws -> Data {
        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = read(socket, &buffer, buffer.count)

        if bytesRead > 0 {
            print("SocketServer: Read \(bytesRead) bytes from socket")
            return Data(bytes: buffer, count: bytesRead)
        } else if bytesRead == 0 {
            print("SocketServer: Socket closed by client (EOF)")
            throw SocketServerError.readFailed(NSError(domain: "SocketServer", code: 0, userInfo: [NSLocalizedDescriptionKey: "Socket closed by client"]))
        } else {
            let error = NSError(domain: "SocketServer", code: Int(errno), userInfo: [NSLocalizedDescriptionKey: String(cString: strerror(errno))])
            print("SocketServer: Error reading from socket: \(error)")
            throw SocketServerError.readFailed(error)
        }
    }

    private func createResponseData(items: [SocketApiKey]) throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(items)
    }

    private func sendResponseData(socket: Int32, data: Data) throws {
        guard let jsonString = String(data: data, encoding: .utf8) else {
            print("SocketServer: Error - cannot convert response data to string")
            writeEmptyResponse(socket: socket)
            return
        }

        // Write to socket with error checking
        let bytesWritten = jsonString.withCString { bytes in
            write(socket, bytes, jsonString.count)
        }

        if bytesWritten < 0 {
            let error = NSError(domain: "SocketServer", code: Int(errno), userInfo: [NSLocalizedDescriptionKey: String(cString: strerror(errno))])
            print("SocketServer: Error writing to socket: \(error)")
            throw SocketServerError.writeFailed(error)
        } else {
            print("SocketServer: Successfully wrote \(bytesWritten) bytes to socket")
        }
    }

    private func writeEmptyResponse(socket: Int32) {
        let empty = "[]"
        let bytesWritten = empty.withCString { bytes in
            write(socket, bytes, empty.count)
        }
        if bytesWritten < 0 {
            let error = NSError(domain: "SocketServer", code: Int(errno), userInfo: [NSLocalizedDescriptionKey: String(cString: strerror(errno))])
            print("SocketServer: Error writing empty response to socket: \(error)")
        }
    }

    private func getClientName(pid: pid_t) -> String {
        guard pid > 0 else {
            return "Unknown Application"
        }

        // Try to get process name using proc_pidpath
        var pathBuffer = [CChar](repeating: 0, count: 4096)
        let result = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))

        if result > 0, let path = String(validatingUTF8: &pathBuffer) {
            let url = URL(fileURLWithPath: path)
            return url.deletingPathExtension().lastPathComponent
        }

        return "Application (PID: \(pid))"
    }
}
