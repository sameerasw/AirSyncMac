import SwiftUI
import UserNotifications

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var clientManager = ClientManager.shared
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupNotificationPermissions()
        createWindow()
        NSApp.activate(ignoringOtherApps: true) // Add this line
    }

    
    private func createWindow() {
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 380), // Adjusted width and height
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
        window.center()
        window.title = "AirSync Mac Client" // More descriptive title
                window.contentView = NSHostingView(rootView: ControlPanelView().environmentObject(ClientManager.shared))
        window.makeKeyAndOrderFront(nil)
        
        // Ensure window persistence
        window.isReleasedWhenClosed = false // Add this line
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
