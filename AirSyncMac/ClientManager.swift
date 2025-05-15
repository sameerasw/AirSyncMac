// AirSyncMac/AirSyncMac/ClientManager.swift
import Combine
import Network
import SwiftUI // For Codable struct if used within view-related logic directly, though here it's for payload

// Payload for sending clipboard to Android
struct ClipboardPushPayload: Codable {
    let type: String
    let text: String
}

class ClientManager: ObservableObject {
    static let shared = ClientManager()

    private let hostKey = "AirSyncMac.Host"
    private let portKey = "AirSyncMac.Port"

    @Published var currentHost: String
    @Published var currentPort: UInt16
    @Published var textToSendToAndroidClipboard: String = "" // For TextEditor binding

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
    @Published var isConnectingOrConnected = false // Combined state for UI

    private var androidClient: AndroidNotificationClient?

    private init() {
        self.currentHost = UserDefaults.standard.string(forKey: hostKey) ?? "192.168.8.101" // Default IP
        let savedPort = UserDefaults.standard.integer(forKey: portKey)
        self.currentPort = savedPort > 0 ? UInt16(savedPort) : 12345 // Default Port
        updateConnectingOrConnectedState() // Initial state
    }

    private func updateConnectingOrConnectedState() {
        isConnectingOrConnected = isConnected || ["Connecting...", "Preparing...", "Setup...", "Waiting..."].contains(connectionStatus)
    }

    func updateConnection(host: String, port: UInt16) {
        currentHost = host
        currentPort = port
        UserDefaults.standard.set(host, forKey: hostKey)
        UserDefaults.standard.set(Int(port), forKey: portKey)
    }

    func connect() {
        // Ensure previous client is disconnected before creating a new one
        if androidClient != nil {
            androidClient?.disconnect()
        }
        androidClient = AndroidNotificationClient(host: currentHost, port: currentPort)
        connectionStatus = "Connecting..." // Set status immediately
        androidClient?.connect()
        // isConnected will be updated by the connectionUpdateHandler
    }

    func disconnect() {
        androidClient?.disconnect()
        // connectionStatus and isConnected will be updated by connectionUpdateHandler or directly if needed
        // For immediate feedback on explicit disconnect:
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
            // Optionally show an alert to the user
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
                // Handle error - perhaps update status
            }
        } catch {
            print("Error encoding clipboard push payload: \(error.localizedDescription)")
            // Handle error - perhaps update status
        }
    }

    // Called by AndroidNotificationClient's stateUpdateHandler
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
