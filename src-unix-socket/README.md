# OpenLocalKeys

A SwiftUI macOS Menu Bar App for managing LLM provider API keys.

## Features

- **Add, Edit, Delete** API keys with an intuitive interface
- **Multi-select** keys for bulk deletion
- **Reorder** keys using up/down arrows to prioritize your most-used providers
- **Show/Hide** sensitive keys with a toggle button
- **Persistent storage** using UserDefaults (survives app restarts)
- **Provider icons** automatically detected based on provider name
- **Secure by design** - keys are masked by default with configurable visibility
- **Unix Domain Socket Server** - Allow other applications to request API keys securely

## Building and Running

### Using Swift Package Manager (SPM)

```bash
# Build the app
swift build

# Run the app
swift run
```

### Using Xcode (Recommended for development)

1. Open this directory in Xcode:
   ```bash
   open Package.swift
   ```

2. Select the "OpenLocalKeys" scheme
3. Press Cmd+R to build and run

## Project Structure

```
OpenLocalKeys/
├── src/
│   ├── OpenLocalKeysApp.swift    # Main app entry point and menu bar setup
│   ├── ContentView.swift          # Main list view with CRUD operations
│   ├── Models/
│   │   ├── ApiKeyItem.swift       # Data model for API key items
│   │   └── Provider.swift         # Provider enum with predefined providers
│   ├── ViewModels/
│   │   └── KeyManagerViewModel.swift  # Business logic and state management
│   ├── Views/
│   │   ├── ItemEditView.swift     # Add/Edit sheet for individual items
│   │   └── KeyRequestDialog.swift # Socket request approval dialog
│   └── Socket/
│       └── SocketServer.swift     # Unix domain socket server
├── SDK-js/                        # Node.js/TypeScript SDK
│   ├── src/
│   │   └── index.ts              # SDK source code
│   ├── package.json              # NPM package configuration
│   └── README.md                 # SDK documentation
├── Package.swift                   # Swift Package Manager configuration
└── README.md
```

## Usage

1. Click the **+** button to add a new API key
2. Fill in the display name, provider name, and private key
3. Click **Save** to store the key
4. Use the **eye icon** to show/hide the full key
5. Use **up/down arrows** to reorder items
6. Click the **pencil icon** to edit or **trash icon** to delete

## Supported Providers

The app automatically detects and shows appropriate icons for:
- OpenAI
- Anthropic
- Google
- Azure
- Cohere
- Hugging Face
- Mistral
- Replicate
- And any custom providers (shows default key icon)

## Customization

- **Status Bar Icon**: Change the `systemSymbolName` in `OpenLocalKeysApp.swift:34`
- **Popover Size**: Modify `contentSize` in `OpenLocalKeysApp.swift:27`
- **Masking Style**: Edit `maskedKey` property in `ApiKeyItem.swift`

## Requirements

- macOS 13.0+
- Xcode 15.0+ or Swift 5.9+

## Unix Domain Socket API

OpenLocalKeys runs a Unix domain socket server that allows other applications to request API keys.

**Socket Path:** `$TMPDIR/com.openlocalkeys.sock`

On macOS, `$TMPDIR` typically resolves to something like `/var/folders/.../T/`. You can get the actual path by running `echo $TMPDIR` in Terminal.

### How to Request Keys

1. Connect to the socket at `$TMPDIR/com.openlocalkeys.sock`
2. Send any message (e.g., "REQUEST_KEYS")
3. Wait for user approval via popup dialog
4. Receive JSON response with selected keys

### Response Format

```json
[
  {
    "displayName": "My OpenAI Key",
    "privateKey": "sk-...",
    "provider": "OpenAI"
  },
  {
    "displayName": "Custom Provider",
    "privateKey": "custom-key",
    "provider": "MyProvider",
    "customProviderName": "MyProvider",
    "customProviderURL": "https://api.example.com/v1"
  }
]
```

### Example Client (Python)

```python
import socket
import json
import os

SOCK_PATH = os.path.join(os.environ.get('TMPDIR', '/tmp'), 'com.openlocalkeys.sock')

def request_keys():
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect(SOCK_PATH)
    sock.send(b"REQUEST_KEYS")
    response = sock.recv(4096)
    sock.close()
    return json.loads(response)

keys = request_keys()
for key in keys:
    print(f"{key['displayName']}: {key['privateKey']}")
```

### Example Client (Bash)

```bash
#!/bin/bash
SOCK_PATH="${TMPDIR:-/tmp}/com.openlocalkeys.sock"
echo "REQUEST_KEYS" | nc -U "$SOCK_PATH" | jq
```

### Node.js/TypeScript SDK

A Node.js SDK is available in the `SDK-js` folder for easy integration with JavaScript/TypeScript projects.

```bash
# Install from local SDK-js directory
npm install ./SDK-js

# Or use directly in your project
import { requestKeys } from 'openlocalkeys';

const keys = await requestKeys();
console.log(keys);
```

See `SDK-js/README.md` for full documentation.
