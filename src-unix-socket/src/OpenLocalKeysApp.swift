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
        // Set up global exception handler
        NSSetUncaughtExceptionHandler { exception in
            print("OpenLocalKeys CRASH: Uncaught exception: \(exception)")
            print("Exception reason: \(exception.reason ?? "Unknown")")
            print("Exception call stack: \(exception.callStackSymbols)")
            // Log the crash but don't crash the app
        }

        // Set up signal handlers for common crash signals
        setupSignalHandlers()

        do {
            // Start the socket server with error handling
            socketServer = SocketServer()
            startSocketServer()

            print("OpenLocalKeys: Socket server started successfully")
        } catch {
            print("OpenLocalKeys Error: Failed to start socket server: \(error)")
        }

        // Create the popover
        do {
            let contentView = ContentView()
            contentViewController = NSHostingController(rootView: contentView)
            popover = NSPopover()
            popover?.contentViewController = contentViewController
            popover?.contentSize = NSSize(width: 500, height: 600)
        } catch {
            print("OpenLocalKeys Error: Failed to create popover: \(error)")
        }

        // Create the status bar item
        do {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

            if let button = statusItem?.button {
                // Set a default icon (you can replace with your own)
                button.image = NSImage(systemSymbolName: "key.fill", accessibilityDescription: "OpenLocalKeys")
                button.image?.isTemplate = true
                button.action = #selector(togglePopover)
                button.target = self
            }
        } catch {
            print("OpenLocalKeys Error: Failed to create status bar item: \(error)")
        }

        // Hide dock icon (optional - comment out if you want a dock icon)
        NSApp.setActivationPolicy(.accessory)
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
            exit(1)
        }

        let signals: [Int32] = [SIGSEGV, SIGBUS, SIGFPE]

        for sigValue in signals {
            // Use C-style signal handler
            _ = signal(sigValue, signalHandler)
        }
    }

    private func startSocketServer() {
        // Stop the existing server if running
        if let server = socketServer, server.isRunning {
            server.stop()
        }

        // Create a new server instance
        socketServer = SocketServer()

        // Start the server with the request handler
        socketServer?.start { [weak self] request in
            guard let self = self else {
                // Send empty response if self is nil
                request.callback([])
                request.closeSocket()
                return
            }

            // Wrap the entire request handling in a try-catch
            do {
                self.handleKeyRequest(request)
            } catch {
                print("OpenLocalKeys Error: Failed to handle key request: \(error)")
                // Send empty response on error
                request.callback([])
                request.closeSocket()
            }

            // Restart the socket server after processing the request
            print("OpenLocalKeys: Request processed, restarting socket server...")
            // Small delay to ensure resources are cleaned up
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.startSocketServer()
            }
        }

        print("OpenLocalKeys: Socket server restarted and ready")
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
        do {
            // Activate app to bring it to front
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)

            // Get the view model from content view
            guard let contentView = contentViewController?.rootView as? ContentView else {
                print("OpenLocalKeys Warning: Could not get ContentView, sending empty response")
                // Send deny response if we can't get the view model
                request.callback([])
                request.closeSocket()
                return
            }

            let viewModel = contentView.viewModel

            // Create and show the request dialog as a window
            let dialog = KeyRequestDialog(
                viewModel: viewModel,
                request: request
            ) { [weak self] approved, items in
                guard let self = self else {
                    // If self is nil, send empty response and close socket
                    request.callback([])
                    request.closeSocket()
                    return
                }

                // Close the window safely
                do {
                    self.keyRequestWindow?.close()
                    self.keyRequestWindow = nil
                } catch {
                    print("OpenLocalKeys Error: Failed to close window: \(error)")
                }

                // Call the callback with the response
                do {
                    if approved {
                        // Convert ApiKeyItem to SocketApiKey safely
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
                        request.callback(socketKeys)
                    } else {
                        request.callback([])
                    }
                } catch {
                    print("OpenLocalKeys Error: Failed to process key selection: \(error)")
                    // Send empty response on error
                    request.callback([])
                }

                // Close the socket after response is sent
                request.closeSocket()

                // Return to accessory mode (hide from dock)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NSApp.setActivationPolicy(.accessory)
                }
            }

            // Create window safely
            let hostingView: NSHostingView<KeyRequestDialog>
            do {
                hostingView = NSHostingView(rootView: dialog)
            } catch {
                print("OpenLocalKeys Error: Failed to create hosting view: \(error)")
                request.callback([])
                request.closeSocket()
                return
            }

            let window: NSWindow
            do {
                window = NSWindow(
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
            } catch {
                print("OpenLocalKeys Error: Failed to create window: \(error)")
                request.callback([])
                request.closeSocket()
                return
            }
        } catch {
            print("OpenLocalKeys Error: Failed to handle key request: \(error)")
            // Send empty response on any error
            request.callback([])
            request.closeSocket()
        }
    }
}
