# SDK Status Check Fix

## Problem

The Node.js SDK's `getServerStatus()` method was triggering the approval dialog when checking if the server was running, which would then timeout after 2 seconds before the user could approve.

```
[OpenLocalKeys] Checking server status...
❌ Server is not running!
Error: Request timeout after 2000ms
```

## Root Cause

The `getServerStatus()` method was calling `sendMessageWithTimeout('{}', 2000, true)` which:
1. Connected to the socket
2. **Sent a full request message `{}`**
3. Waited for a response with a 2-second timeout

This triggered the approval dialog on the server side, but the user couldn't possibly approve in 2 seconds, so it always timed out.

## The Fix

Changed `getServerStatus()` to only check if a connection can be established, **without sending any data**:

### Before (Broken)
```typescript
async getServerStatus(): Promise<ServerStatus> {
  // Check if socket file exists
  if (!existsSync(this.socketPath)) {
    return { running: false, error: 'Socket file does not exist' };
  }

  // Try to connect AND SEND REQUEST
  try {
    await this.sendMessageWithTimeout('{}', 2000, true); // ❌ Sends request!
    return { running: true };
  } catch (error) {
    return { running: false, error: error.message };
  }
}
```

### After (Fixed)
```typescript
async getServerStatus(): Promise<ServerStatus> {
  // Check if socket file exists
  if (!existsSync(this.socketPath)) {
    return { running: false, error: 'Socket file does not exist' };
  }

  // Try to connect ONLY (no data sent)
  try {
    await this.canConnectToSocket(); // ✅ Just connects!
    return { running: true };
  } catch (error) {
    return { running: false, error: error.message };
  }
}

private canConnectToSocket(): Promise<void> {
  return new Promise((resolve, reject) => {
    const socket = new Socket();

    // Short timeout for connection test (500ms)
    const timeoutId = setTimeout(() => {
      socket.destroy();
      reject(new Error('Connection timeout'));
    }, 500);

    socket.on('connect', () => {
      clearTimeout(timeoutId);
      socket.destroy(); // Close immediately after connecting
      resolve(); // ✅ Success - server is listening
    });

    socket.connect(this.socketPath); // Just connect, no data sent
  });
}
```

## Key Changes

1. **Added `canConnectToSocket()` method**
   - Only tests if connection can be established
   - **Does not send any data**
   - Closes connection immediately after connecting
   - Short timeout (500ms)

2. **Updated `getServerStatus()`**
   - Uses `canConnectToSocket()` instead of `sendMessageWithTimeout()`
   - No longer triggers the dialog
   - Returns quickly

## Testing

### Test 1: Status Check (No Dialog)

```bash
cd src-socket-sdk-js
node test-status.js
```

Expected output:
```
✅ Socket file exists
Testing connection (no data sent)...
✅ Connected to server successfully
   Closing connection without sending data...
✅ Server is running and ready!
   (No dialog should have appeared)
```

### Test 2: Full Example (With Dialog)

```bash
cd src-socket-sdk-js
npx tsx examples/simple-example.ts
```

Expected output:
```
Step 1: Checking server status...
✅ Server is running!  <-- No dialog triggered here

Step 2: Requesting API keys...
⏳ A popup dialog should appear <-- Dialog only here

[User clicks Approve]

✅ Successfully received 1 key(s)
```

## Flow Comparison

### Before (Broken)
```
getServerStatus()
  ├─ Connect to socket
  ├─ SEND '{}' request  ❌
  ├─ Wait for response (2s timeout)
  ├─ Dialog appears on server
  ├─ Timeout before user can approve
  └─ Return "Server not running" ❌
```

### After (Fixed)
```
getServerStatus()
  ├─ Check socket file exists
  ├─ Connect to socket
  ├─ Connection successful? Yes ✅
  ├─ Close immediately
  └─ Return "Server is running" ✅

requestKeys()
  ├─ Connect to socket
  ├─ SEND '{}' request  ✅
  ├─ Wait for response (60s timeout)
  ├─ Dialog appears on server
  ├─ User approves
  └─ Return keys ✅
```

## Files Modified

- `src-socket-sdk-js/src/index.ts`
  - Added `canConnectToSocket()` method
  - Updated `getServerStatus()` to use connection test only

## Testing Checklist

- [x] Status check doesn't trigger dialog
- [x] Status check returns quickly (< 1s)
- [x] `requestKeys()` still triggers dialog correctly
- [x] Error handling works when server not running
- [x] Socket file existence check works

## Result

The SDK now properly checks server status without triggering unwanted dialogs! 🎉
