# OpenLocalKeys

A SwiftUI macOS Menu Bar App.

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
│   └── ContentView.swift          # SwiftUI view for the popover content
├── Package.swift                   # Swift Package Manager configuration
└── README.md
```

## Customization

- **Status Bar Icon**: Change the `systemSymbolName` in `OpenLocalKeysApp.swift` (currently `"key.fill"`)
- **Popover Size**: Modify `contentSize` in `OpenLocalKeysApp.swift` (currently 300x400)
- **UI Content**: Edit `ContentView.swift` to customize the popover interface
- **Dock Icon**: Comment out `NSApp.setActivationPolicy(.accessory)` to show a dock icon

## Requirements

- macOS 13.0+
- Xcode 15.0+ or Swift 5.9+
