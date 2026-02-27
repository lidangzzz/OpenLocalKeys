# OLKeys CLI Client

A command-line client for requesting API keys from the OpenLocalKeys socket server.

## Installation

Build the CLI client using Swift Package Manager:

```bash
cd /path/to/OpenLocalKeys
swift build
```

The executable will be created at:
```
.build/debug/olkeys
```

For convenience, you can create a symbolic link:

```bash
ln -s $(pwd)/.build/debug/olkeys /usr/local/bin/olkeys
```

## Usage

### Basic Usage

```bash
# Request API keys (will prompt in the OpenLocalKeys app)
olkeys
```

### Options

```
-h, --help          Show help message
-s, --status        Check if OpenLocalKeys server is running
-p, --path <path>   Custom socket path
-j, --json          Output results as JSON
```

### Examples

```bash
# Check if the server is running
olkeys --status

# Get API keys as JSON
olkeys --json

# Use a custom socket path
olkeys --path /tmp/my-custom-socket.sock

# Get help
olkeys --help
```

## Output Format

### Default Output

```
🔑 Requesting API keys from OpenLocalKeys...
   Please approve the request in the popup dialog...

✅ Received 2 API key(s):

   [1] My OpenAI Key
       Provider: OpenAI
       Key: sk-pt***k123

   [2] Anthropic API Key
       Provider: Anthropic
       Key: sk-1a***b456
```

### JSON Output

```bash
$ olkeys --json
```

```json
[
  {
    "displayName": "My OpenAI Key",
    "privateKey": "sk-pt123k123",
    "provider": "OpenAI",
    "customProviderName": null,
    "customProviderURL": null
  },
  {
    "displayName": "Anthropic API Key",
    "privateKey": "sk-1ab456",
    "provider": "Anthropic",
    "customProviderName": null,
    "customProviderURL": null
  }
]
```

## Integration with Scripts

The CLI client is designed to work well in shell scripts:

```bash
#!/bin/bash

# Get API keys from OpenLocalKeys
KEYS=$(olkeys --json 2>/dev/null)

# Check if we got keys
if [ -z "$KEYS" ]; then
    echo "No keys retrieved"
    exit 1
fi

# Use with jq to extract specific values
OPENAI_KEY=$(echo "$KEYS" | jq -r '.[] | select(.provider=="OpenAI") | .privateKey')

echo "Got OpenAI key: $OPENAI_KEY"
```

## Error Handling

```bash
# Server not running
$ olkeys
❌ Error: Failed to connect to socket server

# Request denied
$ olkeys
⚠️  No keys returned (request was denied or no keys available)
```

## Testing

Run the CLI tests:

```bash
swift test
```

## How It Works

1. **Connection**: The client connects to the Unix domain socket at `~/com.openlocalkeys.sock`
2. **Request**: Sends a "REQUEST_KEYS" message to the server
3. **Approval**: The OpenLocalKeys app shows a dialog asking for user approval
4. **Response**: If approved, the server sends back the selected API keys as JSON
5. **Display**: The client displays the keys (with masking) in the terminal

## Security

- Socket files are created in the system temp directory with proper permissions
- All communication happens over Unix domain sockets (no network exposure)
- The server requires explicit user approval for each request
- Keys are displayed with masking in the terminal (only first/4 characters shown)

## Troubleshooting

### "Server is not running"

Make sure the OpenLocalKeys app is running:

```bash
olkeys --status
```

### "Permission denied"

Check the socket file permissions:

```bash
ls -l /tmp/com.openlocalkeys.sock
```

Should show `srwxr-xr-x` (read/write/execute for owner, read/execute for group/others).

### Connection timeout

If the connection hangs, the server might not be responding. Try restarting the OpenLocalKeys app.
