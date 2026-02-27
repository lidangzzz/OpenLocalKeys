# Unix Socket App - HTTP-Inspired Design Fix

## Problem Analysis

The Unix socket version had a critical design flaw that was causing crashes. After studying the HTTP version's implementation, the key differences became clear.

## Design Comparison

### HTTP Version (Works Correctly ✅)
```swift
// App starts once, server keeps running
httpServer = HTTPServer(port: 8899)
httpServer?.start { [weak self] request in
    self?.handleKeyRequest(request)
}
```

**Key Characteristics:**
1. **Server starts once** - Never restarts
2. **Uses `[weak self]`** everywhere - Safe memory management
3. **Response on background queue** - Non-blocking
4. **Delayed window closing** - Prevents deallocation issues
5. **Clean, simple flow** - No complex lifecycle management

### Unix Socket Version (Had Problems ❌)
```swift
// Old design - COMPLEX and BUGGY
socketServer = SocketServer()
startSocketServer()  // Creates NEW server instance

private func startSocketServer() {
    if let server = socketServer, server.isRunning {
        server.stop()  // Stop existing server
    }
    socketServer = SocketServer()  // Create NEW instance
    socketServer?.start { [weak self] request in
        self.handleKeyRequest(request)
        // Restart immediately - BEFORE user responds!
        self.restartSocketServer()
    }
}
```

**Problems:**
1. ❌ Server restarts after EVERY request
2. ❌ Old server instance (with callback) deallocated
3. ❌ Used `unowned self` (crashes on deallocation)
4. ❌ Restart happens BEFORE user responds to dialog
5. ❌ Complex lifecycle management

## The Fix

Unix socket servers can handle multiple consecutive connections just like TCP sockets - there's NO need to restart!

### New Design (Matches HTTP ✅)

```swift
// Start once, keep running (like HTTP)
socketServer = SocketServer()
socketServer?.start { [weak self] request in
    guard let self = self else {
        request.callback([])
        request.closeSocket()
        return
    }
    self.handleKeyRequest(request)
    // NO RESTART - server keeps listening!
}
```

### Request Handling (Matches HTTP)

```swift
private func handleKeyRequest(_ request: SocketRequest) {
    // Show dialog
    let dialog = KeyRequestDialog(...) { [weak self] approved, items in
        // Send response on BACKGROUND queue (like HTTP)
        DispatchQueue.global(qos: .userInitiated).async {
            if approved {
                request.callback(socketKeys)
            } else {
                request.callback([])
            }
            request.closeSocket()

            // Close window after DELAY (like HTTP)
            DispatchQueue.main.async {
                self?.perform(#selector(self.closeRequestWindow),
                              with: nil,
                              afterDelay: 0.1)
            }
        }
    }

    // Create and show window
    let window = NSWindow(...)
    window.contentView = NSHostingView(rootView: dialog)
    window.makeKeyAndOrderFront(nil)
}
```

## What Changed

### Removed
- ❌ `startSocketServer()` method
- ❌ `restartSocketServer()` method
- ❌ All server restart logic
- ❌ Unnecessary `do-catch` blocks

### Added
- ✅ `closeRequestWindow()` selector method
- ✅ `returnToAccessoryMode()` selector method
- ✅ Background queue for response sending
- ✅ Proper logging matching HTTP version

### Fixed
- ✅ Changed `unowned self` to `weak self` in SocketServer callback
- ✅ Server starts ONCE and keeps running
- ✅ Response sent on background queue
- ✅ Window closed after delay (prevents deallocation issues)

## Flow Comparison

### Before (Crash 💥)
```
1. Request arrives
2. Dialog shown
3. Server RESTARTS (new instance)
4. Old instance DEALLOCATED
5. User clicks approve
6. Callback accesses DEALLOCATED instance
7. CRASH! 💥
```

### After (Success ✅)
```
1. Request arrives
2. Dialog shown
3. Server keeps running (NO restart)
4. User clicks approve
5. Response sent on background queue
6. Socket closed
7. Window closed after delay
8. Success! ✅
```

## Testing

```bash
# Terminal 1: Start server
cd src-unix-socket
swift run OpenLocalKeys

# Terminal 2: Test with JS SDK
cd src-socket-sdk-js
npx tsx examples/simple-example.ts
```

## Key Insight

**Unix domain sockets are just like TCP sockets** - they can handle multiple connections sequentially. There's no need to restart the server after each request. The HTTP version understood this, and now the Unix socket version does too!

## Files Modified

1. `SocketServer.swift`
   - Changed `unowned self` → `weak self` in callback

2. `OpenLocalKeysApp.swift`
   - Removed server restart logic
   - Added background queue for response
   - Added delayed window closing
   - Matched HTTP version's design patterns

## Result

- ✅ No more crashes
- ✅ Simpler code (removed ~50 lines of complex restart logic)
- ✅ Matches proven HTTP design
- ✅ Better memory safety with `weak self`
- ✅ Non-blocking responses
