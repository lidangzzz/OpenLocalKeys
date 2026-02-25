# OpenLocalKeys

A SwiftUI macOS Menu Bar App for managing LLM provider API keys.

## Features

- **Add, Edit, Delete** API keys with an intuitive interface
- **Reorder** keys using up/down arrows to prioritize your most-used providers
- **Show/Hide** sensitive keys with a toggle button
- **Persistent storage** using UserDefaults (survives app restarts)
- **Provider icons** automatically detected based on provider name
- **Secure by design** - keys are masked by default with configurable visibility

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
│   │   └── ApiKeyItem.swift       # Data model for API key items
│   ├── ViewModels/
│   │   └── KeyManagerViewModel.swift  # Business logic and state management
│   └── Views/
│       └── ItemEditView.swift     # Add/Edit sheet for individual items
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
