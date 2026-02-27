# OpenLocalKeys SDK

Node.js/TypeScript SDK for requesting API keys from the OpenLocalKeys macOS app.

## Installation

```bash
npm install openlocalkeys
```

## Prerequisites

- macOS with OpenLocalKeys app running
- Node.js 16+

## Usage

### TypeScript/JavaScript

```typescript
import { OpenLocalKeys, requestKeys } from 'openlocalkeys';

// Method 1: Using the convenience function
const keys = await requestKeys();
console.log(keys);

// Method 2: Using the class
const client = new OpenLocalKeys();
const keys = await client.requestKeys();

// Check if OpenLocalKeys is available
const isAvailable = await client.isAvailable();
console.log('Available:', isAvailable);
```

### CommonJS

```javascript
const { OpenLocalKeys, requestKeys } = require('openlocalkeys');

const keys = await requestKeys();
console.log(keys);
```

## API

### `requestKeys(options?)`

Convenience function to request API keys.

**Parameters:**
- `options.socketPath` - Custom socket path (default: `$TMPDIR/com.openlocalkeys.sock`)
- `options.message` - Request message (default: `"REQUEST_KEYS"`)
- `options.timeout` - Timeout in milliseconds (default: `30000`)

**Returns:** `Promise<ApiKey[]>`

### `OpenLocalKeys` class

#### `new OpenLocalKeys()`

Create a new client instance.

#### `requestKeys(options?)`

Request API keys from OpenLocalKeys.

**Parameters:**
- `options.socketPath` - Custom socket path
- `options.message` - Request message
- `options.timeout` - Timeout in milliseconds

**Returns:** `Promise<ApiKey[]>`

#### `getSocketPath()`

Get the default socket path.

**Returns:** `string`

#### `isAvailable()`

Check if OpenLocalKeys socket is available.

**Returns:** `Promise<boolean>`

## Types

### `ApiKey`

```typescript
interface ApiKey {
  displayName: string;
  privateKey: string;
  provider: string;
  customProviderName?: string;
  customProviderURL?: string;
}
```

### `RequestOptions`

```typescript
interface RequestOptions {
  socketPath?: string;
  message?: string;
  timeout?: number;
}
```

## Example

```typescript
import { OpenLocalKeys } from 'openlocalkeys';

async function getOpenAIKey() {
  const client = new OpenLocalKeys();

  // Check if available
  if (!(await client.isAvailable())) {
    throw new Error('OpenLocalKeys is not running');
  }

  // Request keys
  const keys = await client.requestKeys();

  // Find OpenAI key
  const openaiKey = keys.find(k => k.provider === 'OpenAI');

  if (!openaiKey) {
    throw new Error('No OpenAI key found');
  }

  return openaiKey.privateKey;
}

const apiKey = await getOpenAIKey();
console.log('API Key:', apiKey);
```

## Error Handling

```typescript
import { OpenLocalKeys, OpenLocalKeysError } from 'openlocalkeys';

try {
  const keys = await requestKeys();
} catch (error) {
  if (error instanceof OpenLocalKeysError) {
    console.error('Error code:', error.code);
    console.error('Error message:', error.message);
  }
}
```

### Error Codes

- `TIMEOUT` - Request timed out
- `SOCKET_ERROR` - Socket connection error
- `PARSE_ERROR` - Failed to parse JSON response

## Building from Source

```bash
cd SDK-js
npm install
npm run build
```

## Testing

```bash
npm run test
```

## License

MIT
