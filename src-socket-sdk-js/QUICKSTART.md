# OpenLocalKeys Unix Socket SDK - Quick Start

A quick guide to get started with the OpenLocalKeys Unix Socket SDK for Node.js.

## Prerequisites

1. **macOS** - OpenLocalKeys server runs on macOS
2. **Node.js 16+** - For the SDK
3. **Swift** - To run the OpenLocalKeys server

## Step 1: Start the OpenLocalKeys Server

First, start the Unix socket server:

```bash
cd src-unix-socket
swift run OpenLocalKeys
```

The server will create a socket at `/tmp/com.openlocalkeys.sock` and wait for connections.

You should see:
```
SocketServer: Listening at /tmp/com.openlocalkeys.sock
```

## Step 2: Install the SDK

In a new terminal, install the SDK:

```bash
cd src-socket-sdk-js
npm install
```

## Step 3: Build the SDK

```bash
npm run build
```

## Step 4: Run the Simple Example

```bash
npx ts-node examples/simple-example.ts
```

This will:
1. Check if the server is running
2. Request API keys (shows a popup on macOS)
3. Display the received keys

## Step 5: Try the Express Example

Install Express:

```bash
npm install express
```

Run the server:

```bash
npx ts-node examples/express-server.ts
```

Then in another terminal:

```bash
# Check status
curl http://localhost:3000/api/keys/status

# Request keys
curl -X POST http://localhost:3000/api/keys -H "Content-Type: application/json"

# Visit the web interface
open http://localhost:3000
```

## Basic Usage

```typescript
import { OpenLocalKeys } from './src/index';

const client = new OpenLocalKeys({
  socketPath: '/tmp/com.openlocalkeys.sock',
  verbose: true
});

// Check if server is running
const status = await client.getServerStatus();
console.log('Server running:', status.running);

// Request keys
const keys = await client.requestKeys();
console.log('Received', keys.length, 'keys');

// Use a key
const openaiKey = keys.find(k => k.provider === 'OpenAI');
console.log('Key:', openaiKey?.privateKey);
```

## API Reference

### Constructor Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| socketPath | string | '/tmp/com.openlocalkeys.sock' | Path to Unix socket |
| timeout | number | 300000 | Request timeout (ms) |
| retries | number | 0 | Number of retries |
| retryDelay | number | 1000 | Delay between retries (ms) |
| verbose | boolean | false | Enable logging |

### Methods

- `requestKeys(options?)` - Request API keys from server
- `getServerStatus()` - Check server status
- `isServerRunning()` - Quick check if server is running
- `waitForServer(options?)` - Wait for server to be ready

### Error Codes

- `ConnectionFailed` - Cannot connect to socket
- `Timeout` - Request timed out
- `InvalidResponse` - Server returned invalid response
- `SocketNotFound` - Socket file doesn't exist

## Troubleshooting

### "Socket file does not exist"

The OpenLocalKeys server is not running. Start it:

```bash
swift run OpenLocalKeys
```

### "Connection failed"

The socket exists but the server is not listening. Restart the server.

### "Request timeout"

The popup dialog timed out. Click "Approve" or "Deny" faster, or increase timeout:

```typescript
const keys = await client.requestKeys({ timeout: 120000 });
```

## Comparison: Unix Socket vs HTTP

| Unix Socket SDK | HTTP SDK |
|----------------|----------|
| ⚡ Faster (~1ms) | Standard (~5-10ms) |
| 🔒 Local filesystem | Can be remote |
| No CORS | May need CORS |
| Best for local apps | Best for web apps |

## Next Steps

- Check out the [README.md](./README.md) for detailed documentation
- See [examples/](./examples/) for more examples
- Read the source code in [src/index.ts](./src/index.ts)
