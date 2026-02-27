import SwiftUI
import AppKit
import SocketServer

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
        print("OpenLocalKeys: applicationDidFinishLaunching called")

        // Set up global exception handler
        print("OpenLocalKeys: Setting up exception handler...")
        NSSetUncaughtExceptionHandler { exception in
            print("OpenLocalKeys CRASH: Uncaught exception: \(exception)")
            print("Exception reason: \(exception.reason ?? "Unknown")")
            print("Exception call stack: \(exception.callStackSymbols)")
        }

        // Set up signal handlers
        print("OpenLocalKeys: Setting up signal handlers...")
        setupSignalHandlers()

        // Start the socket server (only once, like the HTTP version)
        print("OpenLocalKeys: Creating SocketServer...")
        socketServer = SocketServer()
        print("OpenLocalKeys: SocketServer created, starting...")
        socketServer?.start { [weak self] request in
            guard let self = self else {
                print("OpenLocalKeys: Warning - self is nil, sending empty response")
                request.callback([])
                request.closeSocket()
                return
            }

            // Handle the request
            self.handleKeyRequest(request)
        }

        print("OpenLocalKeys: Socket server started successfully")

        // Create the popover
        print("OpenLocalKeys: Creating ContentView...")
        let contentView = ContentView()
        print("OpenLocalKeys: Creating NSHostingController...")
        contentViewController = NSHostingController(rootView: contentView)
        print("OpenLocalKeys: Creating NSPopover...")
        popover = NSPopover()
        popover?.contentViewController = contentViewController
        popover?.contentSize = NSSize(width: 500, height: 600)
        print("OpenLocalKeys: Popover created")

        // Create the status bar item
        print("OpenLocalKeys: Creating status bar item...")
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "key.fill", accessibilityDescription: "OpenLocalKeys")
            button.image?.isTemplate = true
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Hide dock icon (accessory mode)
        print("OpenLocalKeys: Setting activation policy to accessory...")
        NSApp.setActivationPolicy(.accessory)
        print("OpenLocalKeys: applicationDidFinishLaunching completed")
    }

    func applicationWillTerminate(_ notification: Notification) {
        print("OpenLocalKeys: Application terminating")

        // Stop socket server gracefully
        if let server = socketServer, server.isRunning {
            print("OpenLocalKeys: Stopping socket server")
            server.stop()
        }

        // Close any open windows
        keyRequestWindow?.close()
        popover?.close()
    }

    private func setupSignalHandlers() {
        // Setup signal handlers for common crash signals
        let signalHandler: @convention(c) (Int32) -> Void = { sig in
            print("OpenLocalKeys CRASH: Received signal \(sig)")
            print("OpenLocalKeys CRASH: Stack trace:")
            Thread.callStackSymbols.forEach { symbol in
                print("  \(symbol)")
            }
            exit(1)
        }

        let signals: [Int32] = [SIGSEGV, SIGBUS, SIGFPE]

        for sigValue in signals {
            // Use C-style signal handler
            _ = signal(sigValue, signalHandler)
        }
    }

    @objc func togglePopover() {
        do {
            guard let button = statusItem?.button else {
                print("OpenLocalKeys Warning: Status bar button not available")
                return
            }

            if let popover = popover, popover.isShown {
                popover.performClose(nil)
            } else {
                popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                // Activate app to ensure popover receives focus
                NSApp.activate(ignoringOtherApps: true)
            }
        } catch {
            print("OpenLocalKeys Error: Failed to toggle popover: \(error)")
        }
    }

    // Close popover when clicking outside
    func applicationDidBecomeActive(_ notification: Notification) {
        // Optional: Handle activation behavior
    }

    func applicationWillResignActive(_ notification: Notification) {
        do {
            // Close popover when losing focus
            popover?.performClose(nil)
            // Post notification to dismiss any open sheets
            NotificationCenter.default.post(name: NSNotification.Name("PopoverWillClose"), object: nil)
        } catch {
            print("OpenLocalKeys Error: Failed to handle resign active: \(error)")
        }
    }

    private func handleKeyRequest(_ request: SocketRequest) {
        print("OpenLocalKeys: handleKeyRequest called")
        print("OpenLocalKeys: Client: \(request.clientName) (PID: \(request.clientPid))")

        // Activate app to bring it to front (keep it in regular mode for dialogs)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // Get the view model from content view
        guard let contentView = contentViewController?.rootView as? ContentView else {
            print("OpenLocalKeys Warning: Could not get ContentView, sending empty response")
            request.callback([])
            request.closeSocket()
            return
        }

        let viewModel = contentView.viewModel

        // Create and show the request dialog
        let dialog = KeyRequestDialog(
            viewModel: viewModel,
            request: request
        ) { [weak self] approved, items in
            guard let self = self else {
                print("OpenLocalKeys: Warning - self is nil in callback")
                request.callback([])
                request.closeSocket()
                return
            }

            print("OpenLocalKeys: Dialog callback - approved: \(approved), items: \(items.count)")

            // Send the response on a background thread to avoid blocking UI (like HTTP version)
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }

                if approved {
                    // Convert ApiKeyItem to SocketApiKey
                    let socketKeys = items.map { item -> SocketApiKey in
                        switch item.provider {
                        case .custom(let name, let url):
                            return SocketApiKey(
                                displayName: item.displayName,
                                privateKey: item.privateKey,
                                provider: item.provider.displayName,
                                customProviderName: name,
                                customProviderURL: url
                            )
                        default:
                            return SocketApiKey(
                                displayName: item.displayName,
                                privateKey: item.privateKey,
                                provider: item.provider.displayName
                            )
                        }
                    }
                    print("OpenLocalKeys: Sending response with \(socketKeys.count) keys")
                    request.callback(socketKeys)
                } else {
                    print("OpenLocalKeys: Sending empty response (denied)")
                    request.callback([])
                }

                // Close socket after response
                request.closeSocket()

                print("OpenLocalKeys: Request handling complete")

                // Close window after delay to avoid deallocation during callback (like HTTP version)
                DispatchQueue.main.async {
                    self.perform(#selector(self.closeRequestWindow), with: nil, afterDelay: 0.1)
                }
            }
        }

        // Create window (like HTTP version)
        print("OpenLocalKeys: Creating dialog window")
        let hostingView = NSHostingView(rootView: dialog)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Key Access Request from \(request.clientName)"
        window.contentView = hostingView
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.level = .floating

        self.keyRequestWindow = window
        print("OpenLocalKeys: Dialog window shown")
    }

    @objc private func closeRequestWindow() {
        print("OpenLocalKeys: Hiding request window (delayed)")
        keyRequestWindow?.orderOut(nil)
        keyRequestWindow = nil
        print("OpenLocalKeys: Window hidden")

        // Schedule return to accessory mode
        perform(#selector(returnToAccessoryMode), with: nil, afterDelay: 0.3)
    }

    @objc private func returnToAccessoryMode() {
        print("OpenLocalKeys: Returning to accessory mode")
        NSApp.setActivationPolicy(.accessory)
    }
}
