# OpenLocalKeys - Multi-Protocol API Key Server

A macOS application that securely manages API keys and provides them to authorized applications through **two different protocols**.

## 🎯 Overview

OpenLocalKeys runs as a menu bar application that:
- Stores your API keys securely
- Shows popup approval dialogs when apps request keys
- Supports **Unix Domain Sockets** (for CLI/native apps)
- Supports **HTTP** (for web apps and browsers)

---

## 📦 Two Versions

### 1. Unix Socket Version (`OpenLocalKeys`)
- **Protocol**: Unix Domain Socket
- **Use Case**: CLI tools, native macOS apps
- **Port**: Socket file at `/tmp/.../com.openlocalkeys.sock`
- **Client**: `olkeys` CLI tool

### 2. HTTP Version (`OpenLocalKeysHTTP`)
- **Protocol**: HTTP on localhost
- **Port**: 8899
- **Use Case**: Web applications, browsers
- **CORS**: Enabled for localhost

---

## 🚀 Quick Start

### Run Unix Socket Version
```bash
swift run OpenLocalKeys
```

### Run HTTP Version
```bash
swift run OpenLocalKeysHTTP
```

### Run CLI Client
```bash
swift run olkeys
```

---

## 📋 Comparison

| Feature | Unix Socket | HTTP |
|---------|-------------|------|
| **Protocol** | Unix Domain Socket | HTTP/TCP |
| **Address** | Socket file path | localhost:8899 |
| **Best For** | CLI tools, native apps | Web apps, browsers |
| **Client** | `olkeys` CLI | Any HTTP client |
| **Browser Support** | ❌ No | ✅ Yes |
| **Speed** | Faster | Slower (overhead) |

---

## 🛠️ Development

### Build All
```bash
swift build
```

### Build Specific Target
```bash
swift build --target OpenLocalKeys      # Unix socket
swift build --target OpenLocalKeysHTTP  # HTTP
swift build --target olkeys             # CLI
```

### Run All
```bash
./run.sh app      # Unix socket version
./run.sh http     # HTTP version
./run.sh cli      # CLI client
```

---

## 📁 Project Structure

```
OpenLocalKeys/
├── Package.swift
├── run.sh                # Convenience script
│
├── src-unix-socket/      # Unix socket version
│   ├── SocketServer/      # Library
│   ├── src/               # App
│   ├── CLI/               # CLI client
│   └── SocketServerTests/
│
└── src-http/              # HTTP version
    ├── HTTPServer/        # Embedded server
    ├── OpenLocalKeysHTTPApp.swift
    ├── HTTPKeyRequestDialog.swift
    ├── Models/
    ├── ViewModels/
    ├── Views/
    ├── README.md
    ├── sdk-http.js        # JavaScript SDK
    └── example.html       # Browser test
```

---

## 💡 Usage Examples

### Unix Socket Client (CLI)
```bash
# Request keys
olkeys

# Get JSON output
olkeys --json

# Check status
olkeys --status
```

### HTTP Client (JavaScript)
```javascript
// From browser or Node.js
const response = await fetch('http://localhost:8899/keys', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({})
});

const keys = await response.json();
```

### HTTP Client (curl)
```bash
curl -X POST http://localhost:8899/keys
```

---

## 🔐 Security

- ✅ **Localhost Only** - No network exposure
- ✅ **Manual Approval** - Every request requires user approval
- ✅ **Multi-Select** - Choose which keys to share
- ✅ **Audit Trail** - See which app requested keys
- ✅ **No Persistence** - Approved per-session only

---

## 📚 Documentation

- [Unix Socket Version README](src-unix-socket/README.md)
- [HTTP Version README](src-http/README.md)
- [JavaScript SDK](src-http/sdk-http.js)
- [Example HTML Page](src-http/example.html)

---

## 🧪 Testing

```bash
# Run all tests
swift test

# Run specific test suite
swift test --filter SocketServerTests
swift test --filter OLKeysClientTests
```

---

## 🐛 Troubleshooting

### "Multiple executable products available"
You must specify which executable to run:
```bash
swift run OpenLocalKeys       # Unix socket
swift run OpenLocalKeysHTTP   # HTTP
swift run olkeys              # CLI
```

Or use the convenience script:
```bash
./run.sh http    # HTTP version
./run.sh app     # Unix socket version
```

### HTTP Server Not Responding
1. Check if the HTTP version is running: `./run.sh http`
2. Verify port: `lsof -i :8899`
3. Check browser console for CORS errors
4. Make sure you're using `http://` not `https://`

### Unix Socket Connection Failed
1. Check if the Unix socket version is running: `./run.sh app`
2. Verify socket file: `ls -la /tmp/com.openlocalkeys.sock`
3. Use the CLI client to test: `./run.sh cli --status`

---

## 📝 License

MIT License - See LICENSE file for details

---

## 🙏 Contributing

Contributions welcome! Please feel free to submit issues or pull requests.

---

## 🎉 Summary

Two protocols, one secure solution. Choose the version that fits your use case!

- **CLI tools** → Unix Socket Version (`swift run OpenLocalKeys`)
- **Web apps** → HTTP Version (`swift run OpenLocalKeysHTTP`)
