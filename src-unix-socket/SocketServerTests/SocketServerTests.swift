import XCTest
@testable import SocketServer
import Foundation

/// Mock SocketClient for testing
final class SocketClient {
    let socketPath: String
    private var socketFd: Int32 = -1

    init(socketPath: String) {
        self.socketPath = socketPath
    }

    func connectToSocket() -> Bool {
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        socketPath.withCString { path in
            strncpy(&addr.sun_path.0, path, MemoryLayout.size(ofValue: addr.sun_path) - 1)
        }

        socketFd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard socketFd != -1 else {
            return false
        }

        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(socketFd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        return result == 0
    }

    func send(message: String) -> Bool {
        guard socketFd != -1 else { return false }
        return message.withCString { bytes in
            write(socketFd, bytes, message.count) > 0
        }
    }

    func receive(timeout: TimeInterval = 5.0) -> String? {
        guard socketFd != -1 else { return nil }

        var buffer = [UInt8](repeating: 0, count: 8192)
        let bytesRead = read(socketFd, &buffer, buffer.count)

        guard bytesRead > 0 else { return nil }

        // Create string and trim null bytes
        let data = Data(bytes: buffer, count: bytesRead)
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func closeSocket() {
        if socketFd != -1 {
            Darwin.close(socketFd)
            socketFd = -1
        }
    }

    deinit {
        closeSocket()
    }
}

final class SocketServerTests: XCTestCase {
    var server: SocketServer!
    var tempSocketPath: String!

    override func setUp() async throws {
        try await super.setUp()
        // Create a unique socket path for each test
        let tempDir = NSTemporaryDirectory()
        tempSocketPath = "\(tempDir)test_openlocalkeys_\(UUID().uuidString).sock"

        // Clean up any existing socket file
        if FileManager.default.fileExists(atPath: tempSocketPath) {
            try? FileManager.default.removeItem(atPath: tempSocketPath)
        }
    }

    override func tearDown() async throws {
        // Stop server and clean up
        server?.stop()
        server = nil

        // Clean up socket file
        if let path = tempSocketPath, FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.removeItem(atPath: path)
        }

        try await super.tearDown()
    }

    // MARK: - Basic Server Tests

    func testServerInitialization() {
        server = SocketServer(socketPath: tempSocketPath)

        XCTAssertNotNil(server)
        XCTAssertFalse(server.isRunning)
        XCTAssertEqual(server.socketFilePath, tempSocketPath)
    }

    func testServerStop() async throws {
        server = SocketServer(socketPath: tempSocketPath)

        server.start { _ in
            // Will be called when client connects
        }

        // Wait for server to start
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        XCTAssertTrue(server.isRunning)

        server.stop()

        // Give it a moment to stop
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

        XCTAssertFalse(server.isRunning)
    }

    // MARK: - Model Tests

    func testSocketApiKeyEncoding() {
        let key = SocketApiKey(
            displayName: "Test",
            privateKey: "sk-test",
            provider: "OpenAI",
            customProviderName: nil,
            customProviderURL: nil
        )

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(key)
            let string = String(data: data, encoding: .utf8)

            XCTAssertTrue(string?.contains("Test") ?? false)
            XCTAssertTrue(string?.contains("sk-test") ?? false)
            XCTAssertTrue(string?.contains("OpenAI") ?? false)
        } catch {
            XCTFail("Encoding failed: \(error)")
        }
    }

    func testSocketApiKeyDecoding() {
        let json = """
        {
            "displayName": "Test",
            "privateKey": "sk-test",
            "provider": "OpenAI",
            "customProviderName": null,
            "customProviderURL": null
        }
        """

        do {
            let decoder = JSONDecoder()
            let key = try decoder.decode(SocketApiKey.self, from: json.data(using: .utf8)!)

            XCTAssertEqual(key.displayName, "Test")
            XCTAssertEqual(key.privateKey, "sk-test")
            XCTAssertEqual(key.provider, "OpenAI")
            XCTAssertNil(key.customProviderName)
            XCTAssertNil(key.customProviderURL)
        } catch {
            XCTFail("Decoding failed: \(error)")
        }
    }

    func testSocketApiKeyWithCustomProvider() {
        let key = SocketApiKey(
            displayName: "Custom",
            privateKey: "custom-key",
            provider: "My Provider",
            customProviderName: "My Provider",
            customProviderURL: "https://api.custom.com"
        )

        XCTAssertEqual(key.displayName, "Custom")
        XCTAssertEqual(key.provider, "My Provider")
        XCTAssertEqual(key.customProviderName, "My Provider")
        XCTAssertEqual(key.customProviderURL, "https://api.custom.com")
    }

    func testSocketApiKeyRoundTrip() {
        let original = SocketApiKey(
            displayName: "RoundTrip",
            privateKey: "sk-round",
            provider: "Test",
            customProviderName: "Custom",
            customProviderURL: "https://custom.com"
        )

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(original)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(SocketApiKey.self, from: data)

            XCTAssertEqual(original.displayName, decoded.displayName)
            XCTAssertEqual(original.privateKey, decoded.privateKey)
            XCTAssertEqual(original.provider, decoded.provider)
            XCTAssertEqual(original.customProviderName, decoded.customProviderName)
            XCTAssertEqual(original.customProviderURL, decoded.customProviderURL)
        } catch {
            XCTFail("Round trip failed: \(error)")
        }
    }

    func testSocketApiKeyArrayEncoding() {
        let keys = [
            SocketApiKey(displayName: "Key 1", privateKey: "sk-1", provider: "OpenAI"),
            SocketApiKey(displayName: "Key 2", privateKey: "sk-2", provider: "Anthropic")
        ]

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(keys)
            let decoder = JSONDecoder()
            let decoded = try decoder.decode([SocketApiKey].self, from: data)

            XCTAssertEqual(decoded.count, 2)
            XCTAssertEqual(decoded[0].displayName, "Key 1")
            XCTAssertEqual(decoded[1].displayName, "Key 2")
        } catch {
            XCTFail("Array encoding/decoding failed: \(error)")
        }
    }

    // MARK: - Integration Tests

    func testSimpleRequestResponse() async throws {
        server = SocketServer(socketPath: tempSocketPath)

        let requestExpectation = expectation(description: "Request received")
        let responseExpectation = expectation(description: "Response received")

        let testKey = SocketApiKey(
            displayName: "Test Key",
            privateKey: "sk-test123",
            provider: "OpenAI"
        )

        server.start { request in
            request.callback([testKey])
            request.closeSocket()
            requestExpectation.fulfill()
        }

        // Wait a bit for server to start
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Create client in a task
        Task {
            let client = SocketClient(socketPath: self.tempSocketPath)
            guard client.connectToSocket() else {
                XCTFail("Client failed to connect")
                return
            }

            guard client.send(message: "REQUEST_KEYS") else {
                XCTFail("Client failed to send")
                return
            }

            let response = client.receive(timeout: 3.0)
            XCTAssertNotNil(response, "Should receive response")

            // Verify the response
            if let data = response?.data(using: .utf8) {
                do {
                    let decoder = JSONDecoder()
                    let keys = try decoder.decode([SocketApiKey].self, from: data)
                    XCTAssertEqual(keys.count, 1)
                    XCTAssertEqual(keys[0].displayName, "Test Key")
                    XCTAssertEqual(keys[0].privateKey, "sk-test123")
                    responseExpectation.fulfill()
                } catch {
                    XCTFail("Failed to decode response: \(error)")
                }
            }

            client.closeSocket()
        }

        await fulfillment(of: [requestExpectation, responseExpectation], timeout: 5.0)
    }

    func testEmptyResponse() async throws {
        server = SocketServer(socketPath: tempSocketPath)

        let requestExpectation = expectation(description: "Request received")
        let responseExpectation = expectation(description: "Response received")

        server.start { request in
            request.callback([])
            request.closeSocket()
            requestExpectation.fulfill()
        }

        // Wait for server to start
        try await Task.sleep(nanoseconds: 100_000_000)

        Task {
            let client = SocketClient(socketPath: self.tempSocketPath)
            guard client.connectToSocket() else {
                XCTFail("Client failed to connect")
                return
            }

            guard client.send(message: "REQUEST_KEYS") else {
                XCTFail("Client failed to send")
                return
            }

            let response = client.receive(timeout: 2.0)
            XCTAssertEqual(response, "[]")
            responseExpectation.fulfill()

            client.closeSocket()
        }

        await fulfillment(of: [requestExpectation, responseExpectation], timeout: 4.0)
    }

    func testMultipleKeysResponse() async throws {
        server = SocketServer(socketPath: tempSocketPath)

        let requestExpectation = expectation(description: "Request received")
        let responseExpectation = expectation(description: "Response received")

        let testKeys = [
            SocketApiKey(displayName: "Key 1", privateKey: "sk-1", provider: "OpenAI"),
            SocketApiKey(displayName: "Key 2", privateKey: "sk-2", provider: "Anthropic"),
            SocketApiKey(displayName: "Key 3", privateKey: "sk-3", provider: "Mistral")
        ]

        server.start { request in
            request.callback(testKeys)
            request.closeSocket()
            requestExpectation.fulfill()
        }

        // Wait for server to start
        try await Task.sleep(nanoseconds: 100_000_000)

        Task {
            let client = SocketClient(socketPath: self.tempSocketPath)
            guard client.connectToSocket() else {
                XCTFail("Client failed to connect")
                return
            }

            guard client.send(message: "REQUEST_KEYS") else {
                XCTFail("Client failed to send")
                return
            }

            let response = client.receive(timeout: 3.0)
            XCTAssertNotNil(response)

            if let data = response?.data(using: .utf8) {
                do {
                    let decoder = JSONDecoder()
                    let keys = try decoder.decode([SocketApiKey].self, from: data)
                    XCTAssertEqual(keys.count, 3)
                    XCTAssertEqual(keys[0].displayName, "Key 1")
                    XCTAssertEqual(keys[1].displayName, "Key 2")
                    XCTAssertEqual(keys[2].displayName, "Key 3")
                    responseExpectation.fulfill()
                } catch {
                    XCTFail("Failed to decode: \(error)")
                }
            }

            client.closeSocket()
        }

        await fulfillment(of: [requestExpectation, responseExpectation], timeout: 5.0)
    }
}
