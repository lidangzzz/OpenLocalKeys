# Unix Socket Server Example

A minimal, educational Unix domain socket server implementation in Swift.

## Features

- Simple Unix domain socket server
- Echo server that returns messages with timestamps
- Clean Swift implementation with proper error handling
- Graceful shutdown on Ctrl+C

## Building

```bash
cd examples/unix-socket-server
swift build
```

## Running

```bash
swift run UnixSocketServerExample
```

The server will start and display its socket path (typically in `/tmp`).

## Testing

In another terminal, send messages to the server using `nc` (netcat):

```bash
echo "Hello, Server!" | nc -U /tmp/example.sock
```

Or use a custom Swift client:

```swift
import Foundation

let socketPath = "/tmp/example.sock"
let clientSocket = socket(AF_UNIX, SOCK_STREAM, 0)

var addr = sockaddr_un()
addr.sun_family = sa_family_t(AF_UNIX)
socketPath.withCString { path in
    strncpy(&addr.sun_path.0, path, MemoryLayout.size(ofValue: addr.sun_path) - 1)
}

withUnsafePointer(to: &addr) {
    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        connect(clientSocket, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
    }
}

// Send message
let message = "Hello from client!\n"
write(clientSocket, message, message.count)

// Read response
var buffer = [UInt8](repeating: 0, count: 4096)
let bytesRead = read(clientSocket, &buffer, buffer.count)
if bytesRead > 0 {
    print(String(bytes: buffer, count: bytesRead))
}

close(clientSocket)
```

## Architecture

```
SimpleSocketServer.swift
├── SimpleSocketServer class
│   ├── start()       - Start the server
│   ├── stop()        - Stop the server
│   └── isRunning     - Check server status
└── SocketError enum
    ├── readFailed
    ├── encodingFailed
    └── connectionClosed
```

## Key Concepts

- **Unix Domain Sockets**: Inter-process communication (IPC) mechanism on Unix-like systems
- **BSD Sockets**: Low-level socket API used in this implementation
- **DispatchSource**: GCD-based event handling for socket activity
- **AF_UNIX**: Address family for Unix domain sockets
- **SOCK_STREAM**: Stream-oriented socket type (TCP-like)

## Comparison with HTTP

| Unix Socket | HTTP |
|-------------|------|
| Faster (no TCP overhead) | Standard, works everywhere |
| Local-only | Can be remote |
| Binary-safe | Text-based (usually) |
| Lower latency | Higher latency |
| No CORS issues | CORS can be problematic |

## Use Cases

- Local API servers
- IPC between processes
- Low-latency communication
- Desktop app extensions
- Local development tools
