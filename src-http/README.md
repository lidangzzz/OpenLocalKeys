# OpenLocalKeys HTTP Server

An HTTP-based API key server that allows web applications and local services to request API keys through a popup approval dialog.

## Features

- ✅ **HTTP Server** - Listens on localhost:8899
- ✅ **CORS Support** - Allows requests from web applications
- ✅ **Popup Approval** - Shows macOS dialog for user approval
- ✅ **Multi-Select** - Approve one or multiple API keys
- ✅ **JSON Response** - Returns keys as JSON
- ✅ **Menu Bar App** - Runs in system tray

## Installation

Build the HTTP version:

```bash
cd /path/to/OpenLocalKeys
swift build --target OpenLocalKeysHTTP
```

## Usage

### Start the Server

```bash
swift run OpenLocalKeysHTTP
```

The server will start listening on `http://localhost:8899`

### Making Requests

#### Using curl

```bash
curl -X POST http://localhost:8899/keys \
  -H "Content-Type: application/json" \
  -d '{}'
```

#### Using fetch (JavaScript)

```javascript
const response = await fetch('http://localhost:8899/keys', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({})
});

const keys = await response.json();
console.log(keys);
```

#### Using Python

```python
import requests

response = requests.post('http://localhost:8899/keys')
keys = response.json()
print(keys)
```

### Response Format

#### Approved Keys

```json
[
  {
    "displayName": "My OpenAI Key",
    "privateKey": "sk-test123...",
    "provider": "OpenAI",
    "customProviderName": null,
    "customProviderURL": null
  }
]
```

#### Denied/Empty Response

```json
[]
```

## API Endpoints

### POST /keys

Request API keys from the server.

**Headers:**
- `Content-Type: application/json` (optional)

**Body:**
```json
{}
```

**Response:**
- `200 OK` - Array of API keys
- `500 Error` - Server error

### OPTIONS /keys

CORS preflight request (handled automatically).

## Example: JavaScript SDK

```javascript
class OpenLocalKeysHTTP {
  constructor(url = 'http://localhost:8899') {
    this.url = url;
  }

  async requestKeys() {
    try {
      const response = await fetch(`${this.url}/keys`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({})
      });

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      const keys = await response.json();
      return keys;
    } catch (error) {
      console.error('Failed to request keys:', error);
      return [];
    }
  }
}

// Usage
const client = new OpenLocalKeysHTTP();
const keys = await client.requestKeys();
console.log('Received keys:', keys);
```

## Security

- **Localhost Only** - Server only listens on 127.0.0.1
- **User Approval** - Every request requires explicit user approval
- **CORS Enabled** - Allows requests from web browsers on localhost
- **No Persistence** - Keys are not stored; approved on-demand

## Troubleshooting

### "Connection Refused"

Make sure the HTTP server is running:
```bash
# Check if port 8899 is listening
lsof -i :8899

# Start the server
swift run OpenLocalKeysHTTP
```

### CORS Errors

If you see CORS errors in your browser console, make sure:
1. The server is running on localhost
2. Your web app is also on localhost
3. You're using http:// not https:// (localhost allows HTTP)

### Empty Response

An empty response means:
- The request was denied by the user, OR
- No API keys are configured in the app

## Comparison: Unix Socket vs HTTP

| Feature | Unix Socket | HTTP |
|---------|-------------|------|
| Transport | Unix Domain Socket | TCP (localhost) |
| Port | File path | 8899 |
| Clients | Native apps | Any HTTP client |
| Web Support | ❌ No | ✅ Yes |
| CORS | N/A | ✅ Yes |
| Use Case | CLI tools, native apps | Web apps, browsers |

## Development

Run tests:
```bash
swift test
```

Build all targets:
```bash
swift build
```

Run specific app:
```bash
# Unix socket version
swift run OpenLocalKeys

# HTTP version
swift run OpenLocalKeysHTTP

# CLI client (for Unix socket)
swift run olkeys
```
