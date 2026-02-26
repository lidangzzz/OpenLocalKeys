import Foundation
import SwiftUI

class SocketServer: ObservableObject {
    private var listenSocket: Int32 = -1
    private var runSource: DispatchSourceRead?
    private let socketPath: String
    private var onIncomingRequest: ((SocketRequest) -> Void)?

    init() {
        let tempDir = NSTemporaryDirectory()
        socketPath = tempDir.hasSuffix("/") ? "\(tempDir)com.openlocalkeys.sock" : "\(tempDir)/com.openlocalkeys.sock"
    }

    struct SocketRequest: Identifiable {
        let id: UUID
        let clientPid: pid_t
        let clientName: String
        let callback: ([ApiKeyItem]) -> Void

        init(clientPid: pid_t, clientName: String, callback: @escaping ([ApiKeyItem]) -> Void) {
            self.id = UUID()
            self.clientPid = clientPid
            self.clientName = clientName
            self.callback = callback
        }
    }

    func start(onIncomingRequest: @escaping (SocketRequest) -> Void) {
        self.onIncomingRequest = onIncomingRequest

        // Remove existing socket file if it exists
        if FileManager.default.fileExists(atPath: socketPath) {
            try? FileManager.default.removeItem(atPath: socketPath)
        }

        // Create socket
        listenSocket = socket(AF_UNIX, SOCK_STREAM, 0)
        guard listenSocket != -1 else {
            print("Failed to create socket")
            return
        }

        // Set socket options
        var value = 1
        setsockopt(listenSocket, SOL_SOCKET, SO_REUSEADDR, &value, socklen_t(MemoryLayout<Int>.size))

        // Bind to socket path
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        strcpy(&addr.sun_path.0, socketPath)

        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(listenSocket, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard bindResult == 0 else {
            print("Failed to bind socket: \(errno)")
            close(listenSocket)
            return
        }

        // Listen for connections
        let listenResult = listen(listenSocket, 5)
        guard listenResult == 0 else {
            print("Failed to listen on socket: \(errno)")
            close(listenSocket)
            return
        }

        print("Socket server listening at \(socketPath)")

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
            close(self.listenSocket)
            try? FileManager.default.removeItem(atPath: self.socketPath)
        }

        runSource?.resume()
    }

    func stop() {
        runSource?.cancel()
        runSource = nil
    }

    private func handleNewConnection() {
        var clientAddr = sockaddr()
        var clientAddrLen = socklen_t(MemoryLayout<sockaddr>.size)

        let clientSocket = accept(listenSocket, &clientAddr, &clientAddrLen)
        guard clientSocket != -1 else {
            print("Failed to accept connection")
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
        let requestData = readFromSocket(clientSocket)

        guard let requestString = String(data: requestData, encoding: .utf8) else {
            print("Failed to read request from client")
            close(clientSocket)
            return
        }

        print("Received request from \(clientName) (PID: \(effectivePid)): \(requestString)")

        // Capture self to prevent it from being deallocated before callback executes
        // Handle request on main thread with UI callback
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                close(clientSocket)
                return
            }

            let request = SocketRequest(clientPid: effectivePid, clientName: clientName) { [weak self] selectedItems in
                guard let self = self else {
                    close(clientSocket)
                    return
                }

                // Explicitly copy the items to avoid threading issues
                // Create the JSON on the main thread where the data is valid
                let jsonData: Data
                do {
                    jsonData = try self.createResponseData(items: selectedItems)
                } catch {
                    print("Error creating response: \(error)")
                    close(clientSocket)
                    return
                }

                // Send response on a background queue to avoid blocking UI
                DispatchQueue.global(qos: .userInitiated).async {
                    self.sendResponseData(socket: clientSocket, data: jsonData)
                    close(clientSocket)
                }
            }

            self.onIncomingRequest?(request)
        }
    }

    private func readFromSocket(_ socket: Int32) -> Data {
        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = read(socket, &buffer, buffer.count)

        if bytesRead > 0 {
            print("Read \(bytesRead) bytes from socket")
            return Data(bytes: buffer, count: bytesRead)
        } else if bytesRead == 0 {
            print("Socket closed by client (EOF)")
        } else {
            print("Error reading from socket: \(errno)")
        }

        return Data()
    }

    private func sendResponse(socket: Int32, items: [ApiKeyItem]) {
        let jsonData: Data
        do {
            jsonData = try createResponseData(items: items)
        } catch {
            print("Error creating response: \(error)")
            writeEmptyResponse(socket: socket)
            return
        }
        sendResponseData(socket: socket, data: jsonData)
    }

    private func createResponseData(items: [ApiKeyItem]) throws -> Data {
        // Create a simple serializable struct for the response
        struct SerializableKeyItem: Codable {
            let displayName: String
            let privateKey: String
            let provider: String
            let customProviderName: String?
            let customProviderURL: String?

            init(item: ApiKeyItem) {
                self.displayName = item.displayName
                self.privateKey = item.privateKey
                self.provider = item.provider.displayName

                switch item.provider {
                case .custom(let name, let url):
                    self.customProviderName = name
                    self.customProviderURL = url
                default:
                    self.customProviderName = nil
                    self.customProviderURL = nil
                }
            }
        }

        // Copy all the data we need into pure Swift structs
        let serializableItems = items.map { SerializableKeyItem(item: $0) }

        // Use JSONEncoder without prettyPrint to avoid extra allocations
        let encoder = JSONEncoder()
        return try encoder.encode(serializableItems)
    }

    private func sendResponseData(socket: Int32, data: Data) {
        guard let jsonString = String(data: data, encoding: .utf8) else {
            writeEmptyResponse(socket: socket)
            return
        }

        // Write to socket with error checking
        let bytesWritten = jsonString.withCString { bytes in
            write(socket, bytes, jsonString.count)
        }

        if bytesWritten < 0 {
            print("Error writing to socket: \(errno)")
        } else {
            print("Successfully wrote \(bytesWritten) bytes to socket")
        }
    }

    private func writeEmptyResponse(socket: Int32) {
        let empty = "[]"
        let bytesWritten = empty.withCString { bytes in
            write(socket, bytes, empty.count)
        }
        if bytesWritten < 0 {
            print("Error writing empty response to socket: \(errno)")
        }
    }

    private func getClientName(pid: pid_t) -> String {
        guard pid > 0 else {
            return "Unknown Application"
        }

        // Try to get process name using proc_pidpath
        // Use PATH_MAX as a reasonable buffer size
        var pathBuffer = [CChar](repeating: 0, count: 4096)
        let result = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))

        if result > 0, let path = String(validatingUTF8: &pathBuffer) {
            let url = URL(fileURLWithPath: path)
            return url.deletingPathExtension().lastPathComponent
        }

        return "Application (PID: \(pid))"
    }
}
