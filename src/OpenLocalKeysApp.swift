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
    var socketServer: SocketServer?
    var keyRequestWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start the socket server
        socketServer = SocketServer()
        socketServer?.start { [weak self] request in
            self?.handleKeyRequest(request)
        }

        // Create the popover
        let contentView = ContentView()
        contentViewController = NSHostingController(rootView: contentView)
        popover = NSPopover()
        popover?.contentViewController = contentViewController
        popover?.contentSize = NSSize(width: 500, height: 600)

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
        // Post notification to dismiss any open sheets
        NotificationCenter.default.post(name: NSNotification.Name("PopoverWillClose"), object: nil)
    }

    private func handleKeyRequest(_ request: SocketServer.SocketRequest) {
        // Activate app to bring it to front
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // Get the view model from content view
        guard let contentView = contentViewController?.rootView as? ContentView else {
            // Send deny response if we can't get the view model
            request.callback([])
            return
        }

        let viewModel = contentView.viewModel

        // Create and show the request dialog as a window
        let dialog = KeyRequestDialog(
            viewModel: viewModel,
            request: request
        ) { [weak self] approved, items in
            // Close the window
            self?.keyRequestWindow?.close()
            self?.keyRequestWindow = nil

            // Call the callback with the response
            if approved {
                request.callback(items)
            } else {
                request.callback([])
            }

            // Return to accessory mode (hide from dock)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApp.setActivationPolicy(.accessory)
            }
        }

        let hostingView = NSHostingView(rootView: dialog)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Key Access Request"
        window.contentView = hostingView
        window.center()
        window.makeKeyAndOrderFront(nil)

        // Keep window on top
        window.level = .floating

        self.keyRequestWindow = window
    }
}
