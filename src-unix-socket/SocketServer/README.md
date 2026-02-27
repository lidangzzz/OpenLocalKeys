# SocketServer

A lightweight Unix domain socket server library for macOS applications. This library provides a simple way to create a socket server that can receive and respond to API key requests.

## Features

- Unix domain socket communication
- Automatic client PID detection on macOS
- Thread-safe request handling
- Swift Concurrency support (`@Sendable`, `Sendable`)
- Simple callback-based API

## Usage

### Basic Setup

```swift
import SocketServer

class AppDelegate: NSObject, NSApplicationDelegate {
    var socketServer: SocketServer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create and start the socket server
        socketServer = SocketServer()
        socketServer?.start { request in
            // Handle incoming request
            print("Request from \(request.clientName) (PID: \(request.clientPid))")

            // Process the request and respond with API keys
            let keys: [SocketApiKey] = [
                SocketApiKey(
                    displayName: "My API Key",
                    privateKey: "sk-...",
                    provider: "OpenAI"
                )
            ]

            // Call the callback to send the response
            request.callback(keys)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Stop the server when the app quits
        socketServer?.stop()
    }
}
```

### Custom Socket Path

```swift
let socketServer = SocketServer(socketPath: "/tmp/my-custom.sock")
socketServer?.start { request in
    // Handle requests
}
```

### Check Server Status

```swift
if socketServer?.isRunning == true {
    print("Server is running at \(socketServer?.socketFilePath ?? "")")
}
```

## Request Handling

When a client connects, the server:

1. Accepts the connection
2. Reads the request message (typically "REQUEST_KEYS")
3. Detects the client's PID and application name
4. Invokes your callback with a `SocketRequest` object
5. Sends your response back as JSON

### Response Format

The server sends responses as JSON arrays:

```json
[
  {
    "displayName": "My OpenAI Key",
    "privateKey": "sk-...",
    "provider": "OpenAI",
    "customProviderName": null,
    "customProviderURL": null
  }
]
```

## Client Example

See the `SDK-js` directory for a Node.js client example:

```javascript
import { OpenLocalKeys } from 'openlocalkeys';

const client = new OpenLocalKeys();
const keys = await client.requestKeys();
console.log(keys);
```

## Thread Safety

The `SocketServer` class is thread-safe and can be used from any thread. The request callback is invoked on the main thread, and the response is sent from a background thread to avoid blocking the UI.

## Platform Support

- macOS 13.0+

## License

MIT
