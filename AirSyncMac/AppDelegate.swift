import SwiftUI
import UserNotifications

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var clientManager = ClientManager.shared

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupNotificationPermissions()
        createWindow()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func createWindow() {
        let contentView = NSHostingView(rootView: ControlPanelView().environmentObject(clientManager))

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 430),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
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
