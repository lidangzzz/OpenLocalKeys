import Foundation
import Network

/// An HTTP server that handles incoming API key requests
public final class HTTPServer: NSObject, ObservableObject, @unchecked Sendable {
    private var listener: NWListener?
    private let port: UInt16
    private var onIncomingRequest: ((HTTPRequest) -> Void)?
    private let queue = DispatchQueue(label: "com.openlocalkeys.httpserver")

    public init(port: UInt16 = 8899) {
        self.port = port
        super.init()
    }

    deinit {
        stop()
    }

    // MARK: - Public Methods

    /// Start the HTTP server
    /// - Parameter onIncomingRequest: Callback invoked when a new request arrives
    public func start(onIncomingRequest: @escaping (HTTPRequest) -> Void) {
        print("HTTPServer: start() called")
        self.onIncomingRequest = onIncomingRequest

        // Create TCP listener on localhost
        print("HTTPServer: Creating NWParameters...")
        let config = NWParameters.tcp
        config.allowLocalEndpointReuse = true
        config.allowFastOpen = true

        do {
            print("HTTPServer: Creating NWListener on port \(self.port)...")
            guard let port = NWEndpoint.Port(rawValue: port) else {
                print("HTTPServer: Invalid port number: \(self.port)")
                return
            }

            listener = try NWListener(using: config, on: port)
            print("HTTPServer: NWListener created successfully")

            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            print("HTTPServer: Connection handler set")

            print("HTTPServer: Starting listener...")
            listener?.start(queue: queue)
            print("HTTPServer: Listener started, now listening on http://localhost:\(self.port)")
        } catch {
            print("HTTPServer: Failed to start listener: \(error)")
        }
    }

    /// Stop the HTTP server
    public func stop() {
        listener?.cancel()
        listener = nil
        print("HTTPServer: Stopped")
    }

    /// Get the server port
    public var serverPort: UInt16 {
        return port
    }

    /// Check if the server is running
    public var isRunning: Bool {
        return listener != nil
    }

    // MARK: - Private Methods

    private func handleConnection(_ connection: NWConnection) {
        print("HTTPServer: New connection received")
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("HTTPServer: Connection ready, receiving request...")
                self.receiveRequest(on: connection)
            case .failed(let error):
                print("HTTPServer: Connection failed: \(error)")
                connection.cancel()
            case .waiting(let error):
                print("HTTPServer: Connection waiting: \(error)")
            default:
                break
            }
        }

        connection.start(queue: queue)
    }

    private func receiveRequest(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }

            if let error = error {
                print("HTTPServer: Receive error: \(error)")
                connection.cancel()
                return
            }

            if let data = data, !data.isEmpty {
                self.processRequest(data: data, connection: connection)
            }

            if isComplete {
                print("HTTPServer: Connection complete")
                connection.cancel()
            }
        }
    }

    private func processRequest(data: Data, connection: NWConnection) {
        print("HTTPServer: Processing request, \(data.count) bytes received")
        guard let requestString = String(data: data, encoding: .utf8) else {
            print("HTTPServer: Failed to decode request as UTF-8")
            sendErrorResponse(connection: connection, statusCode: 400, message: "Bad Request")
            return
        }
        print("HTTPServer: Request string: \(requestString.prefix(200))...")

        // Parse HTTP request
        let lines = requestString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            sendErrorResponse(connection: connection, statusCode: 400, message: "Bad Request")
            return
        }

        let components = requestLine.components(separatedBy: " ")
        guard components.count >= 2,
              let method = HTTPMethod(rawValue: components[0]),
              let path = components[1].removingPercentEncoding else {
            sendErrorResponse(connection: connection, statusCode: 400, message: "Bad Request")
            return
        }

        // Parse headers
        var headers: [String: String] = [:]
        var headerIndex = 1
        while headerIndex < lines.count {
            let line = lines[headerIndex]
            if line.isEmpty {
                break
            }
            let headerParts = line.components(separatedBy: ": ")
            if headerParts.count >= 2 {
                let key = headerParts[0]
                let value = headerParts[1...].joined(separator: ": ")
                headers[key] = value
            }
            headerIndex += 1
        }

        // Handle CORS preflight
        if method == .options {
            sendCORSResponse(connection: connection)
            return
        }

        // Only handle POST requests
        guard method == .post else {
            sendErrorResponse(connection: connection, statusCode: 405, message: "Method Not Allowed")
            return
        }

        // Extract body if present
        var body: Data?
        if headerIndex + 1 < lines.count {
            let bodyLines = lines.dropFirst(headerIndex + 1)
            let bodyString = bodyLines.joined(separator: "\r\n")
            body = bodyString.data(using: .utf8)
        }

        let request = HTTPRequest(
            method: method,
            path: path,
            headers: headers,
            body: body,
            connection: connection,
            origin: headers["Origin"] ?? headers["Referer"]
        )

        print("HTTPServer: Request parsed successfully, dispatching to main thread")
        print("HTTPServer: Method: \(method.rawValue), Path: \(path), Origin: \(request.origin ?? "none")")

        // Notify delegate on main thread
        DispatchQueue.main.async { [weak self] in
            print("HTTPServer: Main thread callback executing")
            self?.onIncomingRequest?(request)
        }
    }

    private func sendCORSResponse(connection: NWConnection) {
        let response = """
        HTTP/1.1 200 OK\r
        Access-Control-Allow-Origin: *\r
        Access-Control-Allow-Methods: POST, OPTIONS\r
        Access-Control-Allow-Headers: Content-Type\r
        Access-Control-Max-Age: 86400\r
        \r
        """

        if let responseData = response.data(using: .utf8) {
            connection.send(content: responseData, completion: .contentProcessed { error in
                if let error = error {
                    print("HTTPServer: Failed to send CORS response: \(error)")
                }
                connection.cancel()
            })
        }
    }

    private func sendErrorResponse(connection: NWConnection, statusCode: Int, message: String) {
        let response = """
        HTTP/1.1 \(statusCode) \(message)\r
        Content-Type: text/plain\r
        Access-Control-Allow-Origin: *\r
        \r
        \(message)
        """

        if let responseData = response.data(using: .utf8) {
            connection.send(content: responseData, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }
}

/// HTTP request methods
public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case options = "OPTIONS"
}

/// Represents an incoming HTTP request
public class HTTPRequest: NSObject, @unchecked Sendable {
    public let method: HTTPMethod
    public let path: String
    public let headers: [String: String]
    public let body: Data?
    private let connection: NWConnection
    public let origin: String?
    private let responseQueue = DispatchQueue(label: "com.openlocalkeys.httpresponse")

    init(
        method: HTTPMethod,
        path: String,
        headers: [String: String],
        body: Data?,
        connection: NWConnection,
        origin: String?
    ) {
        self.method = method
        self.path = path
        self.headers = headers
        self.body = body
        self.connection = connection
        self.origin = origin
    }

    /// Send a successful response with JSON data
    public func respond<T: Encodable>(with data: T) {
        print("HTTPServer: respond() called, encoding data...")
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            let jsonData = try encoder.encode(data)

            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                print("HTTPServer: Failed to convert JSON data to string")
                sendErrorResponse(statusCode: 500, message: "Failed to encode response")
                return
            }

            let response = """
            HTTP/1.1 200 OK\r
            Content-Type: application/json\r
            Access-Control-Allow-Origin: *\r
            Content-Length: \(jsonData.count)\r
            \r
            \(jsonString)
            """

            print("HTTPServer: Sending response, size: \(jsonData.count) bytes")

            if let responseData = response.data(using: .utf8) {
                responseQueue.async { [weak self] in
                    guard let self = self else { return }
                    self.connection.send(content: responseData, completion: .contentProcessed { error in
                        if let error = error {
                            print("HTTPServer: Failed to send response: \(error)")
                        } else {
                            print("HTTPServer: Response sent successfully")
                        }
                        self.connection.cancel()
                    })
                }
            } else {
                print("HTTPServer: Failed to convert response to data")
            }
        } catch {
            print("HTTPServer: Failed to encode data: \(error.localizedDescription)")
            sendErrorResponse(statusCode: 500, message: "Failed to encode data: \(error.localizedDescription)")
        }
    }

    /// Send an empty response
    public func respondEmpty() {
        print("HTTPServer: respondEmpty() called")
        let emptyArray: [String] = []
        respond(with: emptyArray)
    }

    /// Send an error response
    public func sendErrorResponse(statusCode: Int, message: String) {
        print("HTTPServer: sendErrorResponse() called - \(statusCode): \(message)")
        let response = """
        HTTP/1.1 \(statusCode) Error\r
        Content-Type: application/json\r
        Access-Control-Allow-Origin: *\r
        \r
        {"error": "\(message)"}
        """

        if let responseData = response.data(using: .utf8) {
            responseQueue.async { [weak self] in
                guard let self = self else { return }
                self.connection.send(content: responseData, completion: .contentProcessed { _ in
                    print("HTTPServer: Error response sent")
                    self.connection.cancel()
                })
            }
        }
    }
}

/// HTTP Server errors
public enum HTTPServerError: Error, LocalizedError {
    case serverStartFailed(Error)
    case invalidRequest

    public var errorDescription: String? {
        switch self {
        case .serverStartFailed(let error):
            return "Failed to start server: \(error.localizedDescription)"
        case .invalidRequest:
            return "Invalid HTTP request"
        }
    }
}
