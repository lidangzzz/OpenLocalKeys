# OpenLocalKeys HTTP SDK

A TypeScript/JavaScript SDK for communicating with the OpenLocalKeys HTTP server from Node.js and web applications.

## 📦 Installation

```bash
cd src-http-sdk-js
npm install
```

## 🚀 Quick Start

### TypeScript/Node.js

```typescript
import { OpenLocalKeys, APIKey } from 'openlocalkeys-http-sdk';

// Create client
const client = new OpenLocalKeys({
  baseUrl: 'http://localhost:8899',
  timeout: 60000,
  verbose: true
});

// Request keys
const keys = await client.requestKeys();
console.log(`Received ${keys.length} keys`);

keys.forEach(key => {
  console.log(`- ${key.displayName} (${key.provider})`);
  console.log(`  Key: ${key.privateKey}`);
});
```

### JavaScript (CommonJS)

```javascript
const { OpenLocalKeys } = require('openlocalkeys-http-sdk');

const client = new OpenLocalKeys({
  baseUrl: 'http://localhost:8899',
  timeout: 60000
});

const keys = await client.requestKeys();
console.log('Keys:', keys);
```

### Browser/ES Modules

```javascript
import { OpenLocalKeys } from './dist/index.js';

const client = new OpenLocalKeys();
const keys = await client.requestKeys();
```

## 📖 API Reference

### Class: OpenLocalKeys

#### Constructor

```typescript
new OpenLocalKeys(options?: OpenLocalKeysOptions)
```

**Options:**
- `baseUrl?: string` - Server URL (default: `http://localhost:8899`)
- `timeout?: number` - Request timeout in ms (default: `300000` = 5 min)
- `retries?: number` - Number of retries on failure (default: `0`)
- `retryDelay?: number` - Delay between retries in ms (default: `1000`)
- `verbose?: boolean` - Enable logging (default: `false`)
- `fetch?: Function` - Custom fetch implementation

#### Methods

##### `requestKeys(options?: { timeout?: number }): Promise<APIKey[]>`

Request API keys from the server. Shows a popup dialog for user approval.

**Returns:** Promise resolving to array of API keys

**Throws:** `OpenLocalKeysError` on timeout or error

```typescript
const keys = await client.requestKeys();
// or with custom timeout
const keys = await client.requestKeys({ timeout: 30000 });
```

##### `getServerStatus(): Promise<ServerStatus>`

Check if the OpenLocalKeys server is running.

```typescript
const status = await client.getServerStatus();
console.log(status.running); // true/false
console.log(status.baseUrl);  // "http://localhost:8899"
```

##### `isServerRunning(): Promise<boolean>`

Convenience method to check if server is running.

```typescript
if (await client.isServerRunning()) {
  console.log('Server is ready!');
}
```

##### `waitForServer(options?): Promise<boolean>`

Wait for the server to become ready.

**Options:**
- `timeout?: number` - Total wait time in ms (default: `30000`)
- `interval?: number` - Check interval in ms (default: `1000`)
- `maxAttempts?: number` - Maximum check attempts (default: calculated)

```typescript
const ready = await client.waitForServer({
  timeout: 10000,
  interval: 500
});
```

---

### Convenience Functions

```typescript
import { requestKeys, isServerRunning } from 'openlocalkeys-http-sdk';

// Quick request
const keys = await requestKeys();

// Quick status check
const running = await isServerRunning();
```

---

## 🧪 Testing

### Run Tests

```bash
npm test
```

### Run Tests in Watch Mode

```bash
npm run test:watch
```

### Generate Coverage Report

```bash
npm run test:coverage
```

Coverage report will be generated in the `coverage/` directory.

---

## 📝 Examples

### Example 1: Basic Usage

```typescript
import { OpenLocalKeys } from 'openlocalkeys-http-sdk';

const client = new OpenLocalKeys({
  timeout: 60000,
  verbose: true
});

try {
  const keys = await client.requestKeys();
  console.log(`Received ${keys.length} keys`);
} catch (error) {
  console.error('Error:', error.message);
}
```

### Example 2: Express.js Integration

```typescript
import express from 'express';
import { OpenLocalKeys } from 'openlocalkeys-http-sdk';

const app = express();
const olkClient = new OpenLocalKeys();

app.post('/api/keys', async (req, res) => {
  const keys = await olkClient.requestKeys();
  res.json({ keys });
});

app.listen(3000);
```

### Example 3: With Error Handling

```typescript
import { OpenLocalKeys, OpenLocalKeysError, ErrorCode } from 'openlocalkeys-http-sdk';

const client = new OpenLocalKeys({
  retries: 3,
  retryDelay: 2000
});

try {
  const keys = await client.requestKeys();
  console.log('Success:', keys);
} catch (error) {
  if (error instanceof OpenLocalKeysError) {
    switch (error.code) {
      case ErrorCode.Timeout:
        console.error('Request timed out');
        break;
      case ErrorCode.ConnectionFailed:
        console.error('Cannot connect to server');
        break;
      default:
        console.error('Error:', error.message);
    }
  }
}
```

### Example 4: Wait for Server

```typescript
import { OpenLocalKeys } from 'openlocalkeys-http-sdk';

const client = new OpenLocalKeys();

async function start() {
  // Wait for server to be ready (max 30 seconds)
  const ready = await client.waitForServer({
    timeout: 30000,
    interval: 1000
  });

  if (ready) {
    const keys = await client.requestKeys();
    console.log('Got keys:', keys);
  } else {
    console.error('Server did not start in time');
  }
}

start();
```

---

## 📚 TypeScript Support

The SDK is written in TypeScript and includes full type definitions. Types are exported as:

- `OpenLocalKeys` - Main client class
- `APIKey` - API key interface
- `OpenLocalKeysOptions` - Configuration options
- `ServerStatus` - Server status interface
- `OpenLocalKeysError` - Custom error class
- `ErrorCode` - Error code enum

---

## 🔧 Development

### Build

```bash
npm run build
```

### Watch Mode

```bash
npm run watch
```

### Lint

```bash
npm run lint
```

### Format

```bash
npm run format
```

### Clean

```bash
npm run clean
```

---

## 🌐 Browser Usage

For browser usage, use the pre-built JavaScript file: `src-http/sdk-http.js`

```html
<script src="sdk-http.js"></script>
<script>
  const client = new OpenLocalKeysHTTP();
  const keys = await client.requestKeys();
  console.log(keys);
</script>
```

---

## ⚠️ Requirements

- **Node.js:** v16.0.0 or higher
- **OpenLocalKeys HTTP Server:** Must be running on `http://localhost:8899`
- **macOS:** The OpenLocalKeys HTTP server is macOS only

---

## 🐛 Troubleshooting

### "ECONNREFUSED" / Connection Refused

Make sure the OpenLocalKeys HTTP server is running:

```bash
swift run OpenLocalKeysHTTP
```

### Request Timeout

- Increase the timeout value
- Check if the popup dialog is behind other windows
- Make sure you approve the request in the popup

### "Cannot find module 'openlocalkeys-http-sdk'"

Make sure you've built the SDK:

```bash
cd src-http-sdk-js
npm run build
```

For local development:

```typescript
import { OpenLocalKeys } from './src/index';
```

---

## 📄 License

MIT License

---

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

---

## 📞 Support

- Issues: https://github.com/yourusername/OpenLocalKeys/issues
- Documentation: See main README.md
