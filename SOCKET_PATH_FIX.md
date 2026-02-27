# Socket Path Fix - Summary

## Problem
The Unix socket server was using `NSTemporaryDirectory()` which returns a per-user temporary directory (e.g., `/var/folders/qm/h1rpkmy54s3crshf73ck_xm80000gn/T/`), while the Node.js SDK was defaulting to `/tmp/`. This caused connection failures.

## Solution
Both the server and SDK now use a consistent, predictable socket path.

### New Default Socket Path
```
/tmp/com.openlocalkeys.sock
```

## Changes Made

### 1. SocketServer.swift
- Changed default socket path from `NSTemporaryDirectory() + "com.openlocalkeys.sock"` to `/tmp/com.openlocalkeys.sock`
- Added `SocketServer.defaultSocketPath` static property for reference

### 2. SocketClient.swift (CLI)
- Updated to use `SocketServer.defaultSocketPath` instead of `NSTemporaryDirectory()`

### 3. Node.js SDK (src-socket-sdk-js)
- Already using correct default path `/tmp/com.openlocalkeys.sock` (no change needed)

## How to Use

### Start the Server
```bash
cd src-unix-socket
swift run OpenLocalKeys
```

Output:
```
SocketServer: Listening at /tmp/com.openlocalkeys.sock
```

### Test with Node.js SDK
```bash
cd src-socket-sdk-js

# Quick connection test
node test-connection.js

# Run example
npx tsx examples/simple-example.ts
```

### Test with CLI Client
```bash
cd src-unix-socket

# Check status
swift run olkeys --status

# Request keys
swift run olkeys
```

### Test with Netcat
```bash
echo '{}' | nc -U /tmp/com.openlocalkeys.sock
```

## Socket Path Reference

| Component | Socket Path |
|-----------|-------------|
| Swift Server | `/tmp/com.openlocalkeys.sock` |
| Swift CLI Client | `/tmp/com.openlocalkeys.sock` |
| Node.js SDK | `/tmp/com.openlocalkeys.sock` |

All components now use the same default path! ✅
