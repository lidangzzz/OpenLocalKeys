import SwiftUI
import AppKit

@main
struct OpenLocalKeysHTTPApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var contentViewController: NSHostingController<ContentView>?
    var httpServer: HTTPServer?
    var keyRequestWindow: NSWindow?
    private let viewModel: KeyManagerViewModel = KeyManagerViewModel.shared

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

        // Start the HTTP server
        print("OpenLocalKeys: Creating HTTPServer...")
        httpServer = HTTPServer(port: 8899)
        print("OpenLocalKeys: HTTPServer created, starting...")
        httpServer?.start { [weak self] request in
            guard let self = self else {
                print("OpenLocalKeys: Warning - self is nil, sending empty response")
                request.respondEmpty()
                return
            }

            // Handle the request
            self.handleKeyRequest(request)
        }

        print("OpenLocalKeys: HTTP server started successfully")

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

        // Stop HTTP server
        httpServer?.stop()

        // Close windows
        keyRequestWindow?.close()
        popover?.close()
    }

    private func setupSignalHandlers() {
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
            _ = signal(sigValue, signalHandler)
        }
    }

    @objc func togglePopover() {
        guard let button = statusItem?.button else {
            print("OpenLocalKeys Warning: Status bar button not available")
            return
        }

        if let popover = popover, popover.isShown {
            popover.performClose(nil)
        } else {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func applicationWillResignActive(_ notification: Notification) {
        popover?.performClose(nil)
        NotificationCenter.default.post(name: NSNotification.Name("PopoverWillClose"), object: nil)
    }

    @objc private func returnToAccessoryMode() {
        print("OpenLocalKeys: Returning to accessory mode")
        NSApp.setActivationPolicy(.accessory)
    }

    @objc private func closeRequestWindow() {
        print("OpenLocalKeys: Hiding request window (delayed)")
        keyRequestWindow?.orderOut(nil)
        keyRequestWindow = nil
        print("OpenLocalKeys: Window hidden")

        // Schedule return to accessory mode
        perform(#selector(returnToAccessoryMode), with: nil, afterDelay: 0.3)
    }

    private func handleKeyRequest(_ request: HTTPRequest) {
        print("OpenLocalKeys: handleKeyRequest called")
        print("OpenLocalKeys: Path: \(request.path), Origin: \(request.origin ?? "none")")

        // Activate app to bring it to front (keep it in regular mode for dialogs)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // Get client origin information
        let clientOrigin = request.origin ?? "Unknown Application"

        // Create and show the request dialog
        let dialog = HTTPKeyRequestDialog(
            viewModel: viewModel,
            clientOrigin: clientOrigin
        ) { [weak self] approved, items in
            guard let self = self else {
                print("OpenLocalKeys: Warning - self is nil in callback")
                return
            }

            print("OpenLocalKeys: Dialog callback - approved: \(approved), items: \(items.count)")

            // Send the response on a background thread to avoid blocking UI
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }

                if approved {
                    let httpKeys = items.map { item -> HTTPApiKey in
                        switch item.provider {
                        case .custom(let name, let url):
                            return HTTPApiKey(
                                displayName: item.displayName,
                                privateKey: item.privateKey,
                                provider: item.provider.displayName,
                                customProviderName: name,
                                customProviderURL: url
                            )
                        default:
                            return HTTPApiKey(
                                displayName: item.displayName,
                                privateKey: item.privateKey,
                                provider: item.provider.displayName
                            )
                        }
                    }
                    print("OpenLocalKeys: Sending response with \(httpKeys.count) keys")
                    request.respond(with: httpKeys)
                } else {
                    print("OpenLocalKeys: Sending empty response (denied)")
                    request.respondEmpty()
                }

                print("OpenLocalKeys: Request handling complete")

                // Close window after delay to avoid deallocation during callback
                DispatchQueue.main.async {
                    self.perform(#selector(self.closeRequestWindow), with: nil, afterDelay: 0.1)
                }
            }
        }

        // Create window
        print("OpenLocalKeys: Creating dialog window")
        let hostingView = NSHostingView(rootView: dialog)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Key Access Request from \(clientOrigin)"
        window.contentView = hostingView
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.level = .floating

        self.keyRequestWindow = window
        print("OpenLocalKeys: Dialog window shown")
    }
}
