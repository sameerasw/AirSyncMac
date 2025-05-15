import SwiftUI
import UserNotifications

@main
struct AirSyncMac: App {
    // Create the status item
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No visible windows
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    private var window: NSWindow!
    private var clientManager = ClientManager.shared

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupNotificationPermissions()
        createWindow()
        NSApp.activate(ignoringOtherApps: true)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "bell.fill", accessibilityDescription: "App Icon")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Window", action: #selector(showMainWindow), keyEquivalent: "o"))

        menu.addItem(NSMenuItem(title: "About", action: #selector(openAbout), keyEquivalent: "A"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @objc func openAbout() {
            if let url = URL(string: "https://www.sameerasw.com") {
                NSWorkspace.shared.open(url)
            }
        }

        @objc func quit() {
            NSApplication.shared.terminate(nil)
        }
    
    @objc func showMainWindow() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }


    private func createWindow() {
        let contentView = NSHostingView(rootView: ControlPanelView().environmentObject(clientManager))

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 430),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        // ✨ Enable glass effect
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.styleMask.insert(.fullSizeContentView)

        // 🌈 Embed a vibrant NSVisualEffectView behind SwiftUI content
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .sidebar
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false

        let hostingView = contentView
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.addSubview(visualEffectView)
        container.addSubview(hostingView)

        NSLayoutConstraint.activate([
            visualEffectView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            visualEffectView.topAnchor.constraint(equalTo: container.topAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            hostingView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: container.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        window.contentView = container
        window.center()
        window.title = "AirSync Mac Client"
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
    }

    private func setupNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("Notification permissions granted")
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        clientManager.disconnect()
    }
}
