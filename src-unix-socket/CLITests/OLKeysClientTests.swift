import XCTest
@testable import OLKeysClient
import SocketServer
import Foundation

final class OLKeysClientTests: XCTestCase {
    var client: SocketClient!
    var testSocketPath: String!

    override func setUp() async throws {
        try await super.setUp()

        // Create a unique socket path for testing
        let tempDir = NSTemporaryDirectory()
        testSocketPath = "\(tempDir)test_olkeys_\(UUID().uuidString).sock"

        // Clean up any existing socket file
        if FileManager.default.fileExists(atPath: testSocketPath) {
            try? FileManager.default.removeItem(atPath: testSocketPath)
        }

        client = SocketClient(socketPath: testSocketPath)
    }

    override func tearDown() async throws {
        // Clean up socket file
        if let path = testSocketPath, FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.removeItem(atPath: path)
        }

        try await super.tearDown()
    }

    // MARK: - Client Initialization Tests

    func testClientInitialization() {
        XCTAssertNotNil(client)
        XCTAssertEqual(client.socketPath, testSocketPath)
    }

    func testClientDefaultPath() {
        let defaultClient = SocketClient()
        let tempDir = NSTemporaryDirectory()
        let expectedPath = tempDir.hasSuffix("/")
            ? "\(tempDir)com.openlocalkeys.sock"
            : "\(tempDir)/com.openlocalkeys.sock"

        XCTAssertEqual(defaultClient.socketPath, expectedPath)
    }

    // MARK: - Server Status Tests

    func testServerNotRunning() {
        // Server shouldn't be running on a non-existent socket
        XCTAssertFalse(client.isServerRunning())
    }

    // MARK: - Error Handling Tests

    func testConnectionFailedWhenServerNotRunning() {
        XCTAssertThrowsError(try client.requestKeys()) { error in
            guard case SocketClientError.connectionFailed = error else {
                XCTFail("Expected connectionFailed error, got: \(error)")
                return
            }
        }
    }

    // MARK: - Integration Tests (with mock server)

    func testSuccessfulRequestResponse() async throws {
        let requestExpectation = expectation(description: "Request received")
        let responseExpectation = expectation(description: "Response received")

        let testKeys: [SocketApiKey] = [
            SocketApiKey(
                displayName: "Test Key 1",
                privateKey: "sk-test-12345",
                provider: "OpenAI"
            ),
            SocketApiKey(
                displayName: "Test Key 2",
                privateKey: "sk-abc-67890",
                provider: "Anthropic"
            )
        ]

        // Start a mock server
        let serverFd = startMockServer { request in
            XCTAssertEqual(request, "REQUEST_KEYS")
            requestExpectation.fulfill()
            return testKeys
        }

        // Wait a bit for server to start
        try await Task.sleep(nanoseconds: 100_000_000)

        // Test client
        let receivedKeys = try client.requestKeys()

        XCTAssertEqual(receivedKeys.count, 2)
        XCTAssertEqual(receivedKeys[0].displayName, "Test Key 1")
        XCTAssertEqual(receivedKeys[0].privateKey, "sk-test-12345")
        XCTAssertEqual(receivedKeys[0].provider, "OpenAI")
        XCTAssertEqual(receivedKeys[1].displayName, "Test Key 2")
        XCTAssertEqual(receivedKeys[1].provider, "Anthropic")

        responseExpectation.fulfill()

        // Cleanup
        close(serverFd)
        try? FileManager.default.removeItem(atPath: testSocketPath)

        await fulfillment(of: [requestExpectation, responseExpectation], timeout: 5.0)
    }

    func testEmptyResponse() async throws {
        let responseExpectation = expectation(description: "Response received")

        // Start a mock server that returns empty array
        let serverFd = startMockServer { request in
            return [SocketApiKey]()
        }

        // Wait for server to start
        try await Task.sleep(nanoseconds: 100_000_000)

        // Test client
        let receivedKeys = try client.requestKeys()

        XCTAssertTrue(receivedKeys.isEmpty)
        responseExpectation.fulfill()

        // Cleanup
        close(serverFd)
        try? FileManager.default.removeItem(atPath: testSocketPath)

        await fulfillment(of: [responseExpectation], timeout: 3.0)
    }

    func testMultipleKeysResponse() async throws {
        let responseExpectation = expectation(description: "Response received")

        let testKeys: [SocketApiKey] = (1...10).map { index in
            SocketApiKey(
                displayName: "Key \(index)",
                privateKey: "sk-key-\(index)",
                provider: "Provider\(index)"
            )
        }

        // Start mock server
        let serverFd = startMockServer { _ in
            return testKeys
        }

        try await Task.sleep(nanoseconds: 100_000_000)

        let receivedKeys = try client.requestKeys()

        XCTAssertEqual(receivedKeys.count, 10)
        for (index, key) in receivedKeys.enumerated() {
            XCTAssertEqual(key.displayName, "Key \(index + 1)")
            XCTAssertEqual(key.privateKey, "sk-key-\(index + 1)")
        }

        responseExpectation.fulfill()

        // Cleanup
        close(serverFd)
        try? FileManager.default.removeItem(atPath: testSocketPath)

        await fulfillment(of: [responseExpectation], timeout: 3.0)
    }

    // MARK: - Helper Methods

    private func startMockServer(handler: @escaping (String) -> [SocketApiKey]) -> Int32 {
        // Clean up any existing socket file
        if FileManager.default.fileExists(atPath: testSocketPath) {
            try? FileManager.default.removeItem(atPath: testSocketPath)
        }

        // Create socket
        let serverFd = socket(AF_UNIX, SOCK_STREAM, 0)
        XCTAssertGreaterThan(serverFd, 0, "Failed to create server socket")

        // Set socket options
        var value = 1
        setsockopt(serverFd, SOL_SOCKET, SO_REUSEADDR, &value, socklen_t(MemoryLayout<Int>.size))

        // Bind to socket path
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        testSocketPath.withCString { path in
            strncpy(&addr.sun_path.0, path, MemoryLayout.size(ofValue: addr.sun_path) - 1)
        }

        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(serverFd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        XCTAssertEqual(bindResult, 0, "Failed to bind server socket")

        // Listen
        let listenResult = listen(serverFd, 5)
        XCTAssertEqual(listenResult, 0, "Failed to listen on socket")

        // Start accepting connections in background
        DispatchQueue.global(qos: .userInitiated).async {
            var clientAddr = sockaddr()
            var clientAddrLen = socklen_t(MemoryLayout<sockaddr>.size)

            let clientFd = accept(serverFd, &clientAddr, &clientAddrLen)
            guard clientFd != -1 else {
                XCTFail("Failed to accept connection")
                return
            }

            // Read request
            var buffer = [UInt8](repeating: 0, count: 4096)
            let bytesRead = read(clientFd, &buffer, buffer.count)

            guard bytesRead > 0 else {
                close(clientFd)
                return
            }

            let request = String(data: Data(bytes: buffer, count: bytesRead), encoding: .utf8)

            // Handle request and send response
            if let request = request {
                let keys = handler(request)

                do {
                    let encoder = JSONEncoder()
                    let jsonData = try encoder.encode(keys)

                    if let jsonString = String(data: jsonData, encoding: .utf8) {
                        _ = jsonString.withCString { bytes in
                            write(clientFd, bytes, jsonString.count)
                        }
                    }
                } catch {
                    XCTFail("Failed to encode response: \(error)")
                }
            }

            close(clientFd)
        }

        return serverFd
    }
}
