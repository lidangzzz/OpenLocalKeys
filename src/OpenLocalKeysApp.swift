import SwiftUI
import AppKit

@main
struct OpenLocalKeysApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No default window for menu bar app
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var contentViewController: NSHostingController<ContentView>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the popover
        let contentView = ContentView()
        contentViewController = NSHostingController(rootView: contentView)
        popover = NSPopover()
        popover?.contentViewController = contentViewController
        popover?.contentSize = NSSize(width: 300, height: 400)

        // Create the status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            // Set a default icon (you can replace with your own)
            button.image = NSImage(systemSymbolName: "key.fill", accessibilityDescription: "OpenLocalKeys")
            button.image?.isTemplate = true
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Hide dock icon (optional - comment out if you want a dock icon)
        NSApp.setActivationPolicy(.accessory)
    }

    @objc func togglePopover() {
        guard let button = statusItem?.button else { return }

        if let popover = popover, popover.isShown {
            popover.performClose(nil)
        } else {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Activate app to ensure popover receives focus
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // Close popover when clicking outside
    func applicationDidBecomeActive(_ notification: Notification) {
        // Optional: Handle activation behavior
    }

    func applicationWillResignActive(_ notification: Notification) {
        // Close popover when losing focus
        popover?.performClose(nil)
    }
}
