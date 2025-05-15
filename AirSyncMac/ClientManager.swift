// AirSyncMac/AirSyncMac/ClientManager.swift
import Combine
import Network
import SwiftUI
import AppKit
import UserNotifications // Ensure this is imported if ClientManager makes any direct UN calls

// Payload for sending clipboard to Android
struct ClipboardPushPayload: Codable {
    let type: String
    let text: String
}

class ClientManager: ObservableObject {
    static let shared = ClientManager()

    private let hostKey = "AirSyncMac.Host"
    private let portKey = "AirSyncMac.Port"
    private let deviceNameKey = "AirSyncMac.DeviceName"
    private let scrcpyPortKey = "AirSyncMac.ScrcpyPort" // New Key for scrcpy/ADB port

    @Published var currentHost: String
    @Published var currentPort: UInt16 // This is for the app's own communication channel
    @Published var currentScrcpyPort: UInt16 // New: Port for scrcpy's ADB connection
    @Published var androidDeviceName: String
    @Published var textToSendToAndroidClipboard: String = ""

    @Published var isConnected = false {
        didSet {
            updateConnectingOrConnectedState()
        }
    }
    @Published var connectionStatus = "Disconnected" {
        didSet {
            updateConnectingOrConnectedState()
        }
    }
    @Published var isConnectingOrConnected = false

    private var androidClient: AndroidNotificationClient?

    private init() {
        self.currentHost = UserDefaults.standard.string(forKey: hostKey) ?? "192.168.8.101"
        let savedPort = UserDefaults.standard.integer(forKey: portKey)
        self.currentPort = savedPort > 0 ? UInt16(savedPort) : 12345
        
        let savedScrcpyPort = UserDefaults.standard.integer(forKey: scrcpyPortKey) // New
        self.currentScrcpyPort = savedScrcpyPort > 0 ? UInt16(savedScrcpyPort) : 5555 // New, default 5555
        
        self.androidDeviceName = UserDefaults.standard.string(forKey: deviceNameKey) ?? "Phone"
        
        AndroidNotificationClient.registerNotificationCategories()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("AirSyncMac: Notification permission granted.")
            } else if let error = error {
                print("AirSyncMac: Notification permission error: \(error.localizedDescription)")
            } else {
                print("AirSyncMac: Notification permission denied.")
            }
        }
        updateConnectingOrConnectedState()
    }

    private func updateConnectingOrConnectedState() {
        isConnectingOrConnected = isConnected || ["Connecting...", "Preparing...", "Setup...", "Waiting..."].contains(where: connectionStatus.starts(with:))
    }

    // Updated function to also handle device name and scrcpy port
    func updateSettings(host: String, port: UInt16, deviceName: String, scrcpyPort: UInt16) { // MODIFIED signature
        currentHost = host
        currentPort = port
        currentScrcpyPort = scrcpyPort // New
        androidDeviceName = deviceName.isEmpty ? "Phone" : deviceName

        UserDefaults.standard.set(host, forKey: hostKey)
        UserDefaults.standard.set(Int(port), forKey: portKey)
        UserDefaults.standard.set(Int(scrcpyPort), forKey: scrcpyPortKey) // New
        UserDefaults.standard.set(androidDeviceName, forKey: deviceNameKey)
        
        print("AirSyncMac: Settings updated. Host: \(currentHost), App Port: \(currentPort), Device Name: \(androidDeviceName), Scrcpy/ADB Port: \(currentScrcpyPort)")

        if isConnected || isConnectingOrConnected {
             print("AirSyncMac: Settings changed while connected/connecting. Disconnecting to apply new settings on next connect.")
             disconnect()
        }
    }

    func connect() {
        if androidClient != nil {
            androidClient?.disconnect()
            androidClient = nil
        }
        androidClient = AndroidNotificationClient(host: currentHost, port: currentPort) // Scrcpy port is read by client from ClientManager.shared
        connectionStatus = "Connecting..."
        androidClient?.connect()
    }

    func disconnect() {
        androidClient?.disconnect()
        isConnected = false
        connectionStatus = "Disconnected"
    }

    func sendClipboardToAndroid() {
        guard !textToSendToAndroidClipboard.isEmpty else {
            print("Clipboard text to send is empty.")
            return
        }
        guard isConnected, let client = androidClient else {
            print("Not connected. Cannot send clipboard.")
            return
        }
        let payload = ClipboardPushPayload(type: "clipboard_push_to_android", text: textToSendToAndroidClipboard)
        let encoder = JSONEncoder()
        do {
            let jsonData = try encoder.encode(payload)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                client.send(string: jsonString)
            } else {
                print("Error converting JSON data to string for sending.")
            }
        } catch {
            print("Error encoding clipboard push payload: \(error.localizedDescription)")
        }
    }
    
    func sendMacClipboardToAndroid() {
            // Get the current string content from the general pasteboard
            guard let clipboardString = NSPasteboard.general.string(forType: .string) else {
                print("AirSyncMac ClientManager: Mac clipboard is empty or does not contain a string.")
                // Optionally, update connectionStatus to give user feedback
                // self.connectionStatus = "Mac clipboard empty"
                // Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { _ in if self.connectionStatus == "Mac clipboard empty" { self.connectionStatus = self.isConnected ? "Connected" : "Disconnected" } }
                return
            }

            guard !clipboardString.isEmpty else {
                print("AirSyncMac ClientManager: Mac clipboard string is empty.")
                return
            }

            guard isConnected, let client = androidClient else {
                print("AirSyncMac ClientManager: Not connected. Cannot send Mac clipboard.")
                // Optionally, show an alert to the user
                return
            }

            print("AirSyncMac ClientManager: Sending Mac clipboard content: \(clipboardString.prefix(50))...")

            let payload = ClipboardPushPayload(type: "clipboard_push_to_android", text: clipboardString)
            let encoder = JSONEncoder()

            do {
                let jsonData = try encoder.encode(payload)
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    client.send(string: jsonString)
                    // Optionally provide feedback that it was sent
                    // self.connectionStatus = "Mac clipboard sent!"
                    // Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { _ in if self.connectionStatus == "Mac clipboard sent!" { self.connectionStatus = self.isConnected ? "Connected" : "Disconnected" } }

                } else {
                    print("AirSyncMac ClientManager: Error converting Mac clipboard JSON data to string for sending.")
                }
            } catch {
                print("AirSyncMac ClientManager: Error encoding Mac clipboard push payload: \(error.localizedDescription)")
            }
        }

    public func connectionUpdateHandler(_ state: NWConnection.State) {
        DispatchQueue.main.async {
            switch state {
            case .setup:
                self.connectionStatus = "Setup..."
                self.isConnected = false
            case .waiting(let error):
                self.connectionStatus = "Waiting: \(error.localizedDescription)... Retrying."
                self.isConnected = false
            case .preparing:
                self.connectionStatus = "Preparing..."
                self.isConnected = false
            case .ready:
                self.connectionStatus = "Connected"
                self.isConnected = true
            case .failed(let error):
                self.connectionStatus = "Failed: \(error.localizedDescription). Retrying."
                self.isConnected = false
            case .cancelled:
                self.connectionStatus = "Disconnected"
                self.isConnected = false
            @unknown default:
                self.connectionStatus = "Unknown state"
                self.isConnected = false
            }
        }
    }
}
