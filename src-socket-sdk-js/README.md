# OpenLocalKeys Unix Socket SDK

A TypeScript/JavaScript SDK for communicating with the OpenLocalKeys Unix socket server. This SDK allows Node.js applications to securely request API keys through Unix domain sockets on macOS.

## Features

- 🔒 Secure Unix domain socket communication
- ⚡ Faster than HTTP (no TCP overhead)
- 🎯 Type-safe TypeScript API
- 🔄 Automatic retry logic
- ⏱️ Configurable timeouts
- 📊 Server status checking
- 📝 Verbose logging mode

## Installation

```bash
npm install openlocalkeys-socket-sdk
```

## Quick Start

```typescript
import { OpenLocalKeys } from 'openlocalkeys-socket-sdk';

// Initialize the client
const client = new OpenLocalKeys({
  socketPath: '/tmp/com.openlocalkeys.sock',
  timeout: 60000,
  verbose: true
});

// Request API keys
const keys = await client.requestKeys();
console.log(`Received ${keys.length} keys`);

// Use a key
const openaiKey = keys.find(k => k.provider === 'OpenAI');
if (openaiKey) {
  console.log('Using:', openaiKey.displayName);
  // Make API calls with openaiKey.privateKey
}
```

## API Reference

### `OpenLocalKeys`

Main client class for interacting with the OpenLocalKeys socket server.

#### Constructor Options

```typescript
interface OpenLocalKeysOptions {
  socketPath?: string;     // Default: '/tmp/com.openlocalkeys.sock'
  timeout?: number;        // Default: 300000 (5 minutes)
  retries?: number;        // Default: 0
  retryDelay?: number;     // Default: 1000ms
  verbose?: boolean;       // Default: false
}
```

#### Methods

##### `requestKeys(options?)`

Request API keys from the server. Shows a popup dialog on macOS for user approval.

```typescript
const keys = await client.requestKeys({
  timeout: 30000  // Custom timeout for this request
});
```

##### `getServerStatus()`

Check if the server is running and accessible.

```typescript
const status = await client.getServerStatus();
console.log(status.running);  // true/false
console.log(status.error);    // Error message if not running
```

##### `isServerRunning()`

Quick check if server is running.

```typescript
if (await client.isServerRunning()) {
  console.log('Server is ready');
}
```

##### `waitForServer(options?)`

Wait for the server to become available.

```typescript
const ready = await client.waitForServer({
  timeout: 30000,      // Max wait time
  interval: 1000,      // Check interval
  maxAttempts: 30      // Max attempts
});
```

### Types

#### `APIKey`

Represents an API key returned from the server.

```typescript
interface APIKey {
  displayName: string;
  privateKey: string;
  provider: string;
  customProviderName?: string;
  customProviderURL?: string;
}
```

#### `ServerStatus`

Status information about the server.

```typescript
interface ServerStatus {
  socketPath: string;
  running: boolean;
  timestamp: string;
  error?: string;
}
```

#### `ErrorCode`

Error codes for better error handling.

```typescript
enum ErrorCode {
  ConnectionFailed = 'CONNECTION_FAILED',
  Timeout = 'TIMEOUT',
  InvalidResponse = 'INVALID_RESPONSE',
  ServerError = 'SERVER_ERROR',
  RequestCancelled = 'REQUEST_CANCELLED',
  SocketNotFound = 'SOCKET_NOT_FOUND'
}
```

## Convenience Functions

Quick functions for common operations:

```typescript
import { requestKeys, isServerRunning } from 'openlocalkeys-socket-sdk';

// Quick request
const keys = await requestKeys({ verbose: true });

// Quick status check
if (await isServerRunning()) {
  // Server is ready
}
```

## Error Handling

The SDK provides detailed error information:

```typescript
import { OpenLocalKeys, OpenLocalKeysError, ErrorCode } from 'openlocalkeys-socket-sdk';

const client = new OpenLocalKeys();

try {
  const keys = await client.requestKeys();
} catch (error) {
  if (error instanceof OpenLocalKeysError) {
    switch (error.code) {
      case ErrorCode.Timeout:
        console.error('Request timed out');
        break;
      case ErrorCode.ConnectionFailed:
        console.error('Cannot connect to server:', error.message);
        break;
      case ErrorCode.SocketNotFound:
        console.error('Socket file not found. Is the server running?');
        break;
    }
  }
}
```

## Examples

### Express.js Integration

```typescript
import express from 'express';
import { OpenLocalKeys } from 'openlocalkeys-socket-sdk';

const app = express();
const client = new OpenLocalKeys({ verbose: true });

app.post('/api/keys', async (req, res) => {
  try {
    // Check server status
    const status = await client.getServerStatus();
    if (!status.running) {
      return res.status(503).json({
        error: 'OpenLocalKeys server not running'
      });
    }

    // Request keys
    const keys = await client.requestKeys();
    res.json({ keys, count: keys.length });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.listen(3000);
```

### CLI Tool

```typescript
#!/usr/bin/env node
import { OpenLocalKeys } from 'openlocalkeys-socket-sdk';

async function main() {
  const client = new OpenLocalKeys({ verbose: true });

  console.log('Checking server status...');
  const status = await client.getServerStatus();

  if (!status.running) {
    console.error('Server not running:', status.error);
    process.exit(1);
  }

  console.log('Requesting keys...');
  const keys = await client.requestKeys();

  console.log(`\nReceived ${keys.length} keys:`);
  keys.forEach(key => {
    console.log(`  - ${key.displayName} (${key.provider})`);
  });
}

main().catch(console.error);
```

## Comparison with HTTP SDK

| Feature | Unix Socket SDK | HTTP SDK |
|---------|----------------|----------|
| Speed | ⚡ Faster (no TCP overhead) | Standard HTTP |
| Security | 🔒 Local filesystem only | Can be secured |
| Use Case | Local Node.js apps | Web apps, remote access |
| Latency | ~1ms | ~5-10ms |
| CORS | Not applicable | May need handling |

## Requirements

- Node.js >= 16.0.0
- macOS (for OpenLocalKeys server)
- OpenLocalKeys Unix socket server running

## Building

```bash
npm run build
```

## Testing

```bash
npm test
```

## License

MIT
