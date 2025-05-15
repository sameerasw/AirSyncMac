// AirSyncMac/AirSyncMac/ClientManager.swift
import Combine
import Network
import SwiftUI
import AppKit

// Payload for sending clipboard to Android
struct ClipboardPushPayload: Codable {
    let type: String
    let text: String
}

class ClientManager: ObservableObject {
    static let shared = ClientManager()

    private let hostKey = "AirSyncMac.Host"
    private let portKey = "AirSyncMac.Port"
    private let deviceNameKey = "AirSyncMac.DeviceName" // New Key

    @Published var currentHost: String
    @Published var currentPort: UInt16
    @Published var androidDeviceName: String // New Published Property
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
        self.androidDeviceName = UserDefaults.standard.string(forKey: deviceNameKey) ?? "Phone" // Initialize device name
        updateConnectingOrConnectedState()
    }

    private func updateConnectingOrConnectedState() {
        isConnectingOrConnected = isConnected || ["Connecting...", "Preparing...", "Setup...", "Waiting..."].contains(connectionStatus)
    }

    // Updated function to also handle device name
    func updateSettings(host: String, port: UInt16, deviceName: String) {
        currentHost = host
        currentPort = port
        androidDeviceName = deviceName.isEmpty ? "Phone" : deviceName // Ensure not empty, default to "Phone"

        UserDefaults.standard.set(host, forKey: hostKey)
        UserDefaults.standard.set(Int(port), forKey: portKey)
        UserDefaults.standard.set(androidDeviceName, forKey: deviceNameKey) // Save device name
        
        print("AirSyncMac: Settings updated. Host: \(currentHost), Port: \(currentPort), Device Name: \(androidDeviceName)")

        // If connection settings change and we are connected, we might want to disconnect and reconnect.
        // Or, just update for next connection attempt. For now, this just updates the settings.
        // If you want to force a reconnect with new settings:
        // if isConnected || isConnectingOrConnected {
        //     disconnect()
        //     // Optionally auto-connect, or let the user click "Connect" again
        //     // connect()
        // }
    }


    func connect() {
        if androidClient != nil {
            androidClient?.disconnect()
        }
        // Pass the device name to the AndroidNotificationClient if it needs it directly,
        // or it can fetch it from ClientManager.shared.androidDeviceName
        androidClient = AndroidNotificationClient(host: currentHost, port: currentPort)
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
