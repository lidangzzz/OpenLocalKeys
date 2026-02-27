# Server Crash Fix - Summary

## Problem
The macOS server app crashed with the following error when the JS client requested keys:

```
Fatal error: Attempted to read an unowned reference but the object was already deallocated
```

## Root Cause
The crash was caused by a **race condition** in the socket server lifecycle:

1. **Request Received**: JS client connects and sends `{}`
2. **Dialog Shown**: Server shows the approval dialog
3. **Server Restarted**: Server was immediately restarted (creating new `SocketServer` instance)
4. **Old Instance Deallocated**: The old `SocketServer` instance (holding the callback) was deallocated
5. **User Approves**: User clicks "Approve" in the dialog
6. **Callback Invoked**: Callback tries to access the deallocated `SocketServer` instance via `unowned self`
7. **CRASH**: `unowned` reference to deallocated object causes fatal error

## Changes Made

### 1. SocketServer.swift - Changed `unowned` to `weak`

**Before:**
```swift
callback: { [unowned self, socketFd] selectedItems in
    jsonData = try self.createResponseData(items: selectedItems)
    // ...
}
```

**After:**
```swift
callback: { [weak self, socketFd] selectedItems in
    guard let self = self else {
        print("SocketServer: Warning - SocketServer was deallocated")
        close(socketFd)
        return
    }
    jsonData = try self.createResponseData(items: selectedItems)
    // ...
}
```

**Rationale**: `weak` references gracefully handle deallocation by becoming `nil`, while `unowned` causes a crash.

### 2. OpenLocalKeysApp.swift - Fixed Server Restart Timing

**Before:**
```swift
socketServer?.start { [weak self] request in
    self.handleKeyRequest(request)  // Shows dialog, returns immediately

    // Server restarted HERE - before user responds!
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        self.startSocketServer()
    }
}
```

**After:**
```swift
socketServer?.start { [weak self] request in
    self.handleKeyRequest(request)  // Shows dialog, returns immediately
    // No restart here - wait for request to complete
}

// Added helper method
private func restartSocketServer() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        self?.startSocketServer()
    }
}

// Restart called AFTER response sent and socket closed
// In the dialog callback:
request.closeSocket()
self.restartSocketServer()  // Restart AFTER request complete
```

**Rationale**: The server should only restart after the request is fully complete (response sent, socket closed), not immediately after receiving the request.

## Flow After Fix

1. **Request Received**: JS client connects and sends `{}`
2. **Dialog Shown**: Server shows the approval dialog
3. **User Approves**: User clicks "Approve"
4. **Response Sent**: Callback sends response to client
5. **Socket Closed**: Connection is closed
6. **Server Restarted**: Server is now restarted (ready for new connections)
7. **Success**: No crash! ✅

## Testing

1. Start the server:
   ```bash
   cd src-unix-socket
   swift run OpenLocalKeys
   ```

2. Test with Node.js SDK:
   ```bash
   cd src-socket-sdk-js
   npx tsx examples/simple-example.ts
   ```

3. Click "Approve" in the dialog - should work without crash!

## Files Modified

1. `src-unix-socket/SocketServer/SocketServer.swift` - Changed `unowned self` to `weak self`
2. `src-unix-socket/src/OpenLocalKeysApp.swift` - Fixed server restart timing
