// AirSyncMac/AirSyncMac/AndroidnotificationClient.swift
import Foundation
import Network
import UserNotifications
import AppKit

// Matches the JSON structure for notifications from Android
struct NotificationData: Codable {
    let app: String?
    let title: String?
    let text: String?
    let iconBase64String: String? // Swift property name

    enum CodingKeys: String, CodingKey {
        case app, title, text
        case iconBase64String = "icon_base64" // JSON key expected from Android (as per Python script)
    }
}

// Matches the JSON structure for clipboard updates from Android
struct ClipboardData: Codable {
    let text: String?
    // Assumes the JSON from Android for clipboard will also have a "type": "clipboard" field,
    // which will be checked before decoding into this struct.
}

// Helper struct to peek at the "type" field of any incoming JSON message
struct MessageTypePeek: Decodable {
    let type: String?
}

class AndroidNotificationClient {
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.airsync.notification.client", qos: .userInitiated)
    private var buffer = Data()
    private var isActuallyConnected = false
    private var reconnectTimer: Timer?
    
    let host: NWEndpoint.Host
    let port: NWEndpoint.Port
    
    init(host: String, port: UInt16) {
        self.host = NWEndpoint.Host(host)
        self.port = NWEndpoint.Port(integerLiteral: port)
        print("AirSyncMac: AndroidNotificationClient initialized for \(host):\(port)")
    }
    
    func connect() {
        print("AirSyncMac: Attempting to connect to \(host.debugDescription):\(port.debugDescription)...")
        let params = NWParameters.tcp
        // Allow insecure connections for local network if needed (though .tcp is generally fine)
        // params.acceptUnverifiedTLS = true // Only if TLS is attempted and self-signed
        
        connection = NWConnection(host: host, port: port, using: params)
        
        connection?.stateUpdateHandler = { [weak self] newState in
            guard let self = self else { return }
            
            // Always notify ClientManager on the main thread
            DispatchQueue.main.async {
                ClientManager.shared.connectionUpdateHandler(newState)
            }
            
            switch newState {
            case .ready:
                print("AirSyncMac: Connection state READY. Client connected to Android device.")
                self.handleConnectionReady()
            case .failed(let error):
                print("AirSyncMac: Connection state FAILED. Error: \(error.localizedDescription)")
                self.handleConnectionError(error)
            case .waiting(let error):
                print("AirSyncMac: Connection state WAITING. Error: \(error.localizedDescription). Will keep trying.")
                self.isActuallyConnected = false // Not fully connected yet
                // Reconnect logic should be triggered by ClientManager or scheduleReconnect
                self.scheduleReconnect() // Ensure reconnect is scheduled if stuck in waiting
            case .setup:
                print("AirSyncMac: Connection state SETUP.")
                self.isActuallyConnected = false
            case .preparing:
                print("AirSyncMac: Connection state PREPARING.")
                self.isActuallyConnected = false
            case .cancelled:
                print("AirSyncMac: Connection state CANCELLED.")
                self.isActuallyConnected = false
                self.reconnectTimer?.invalidate() // Stop trying to reconnect if explicitly cancelled
            @unknown default:
                print("AirSyncMac: Connection state UNKNOWN.")
                self.isActuallyConnected = false
            }
        }
        connection?.start(queue: queue)
    }
    

    private func handleConnectionReady() {
            isActuallyConnected = true
            reconnectTimer?.invalidate()
            DispatchQueue.main.async {
                 // Use the configured device name
                 let deviceName = ClientManager.shared.androidDeviceName
                 self.showSystemNotification(title: "AirSync", body: "Connected to \(deviceName) (\(self.host.debugDescription))")
            }
            receiveData()
        }

    private func handleConnectionError(_ error: NWError) {
        isActuallyConnected = false
        let errorMessage = error.localizedDescription
        DispatchQueue.main.async {
            self.showSystemNotification(title: "AirSync Disconnected", body: "Error: \(errorMessage). Retrying...")
        }
        scheduleReconnect()
    }

    private func scheduleReconnect() {
        reconnectTimer?.invalidate()
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.isActuallyConnected else { return }
            print("AirSyncMac: Scheduling reconnect in 10 seconds.")
            self.reconnectTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
                print("AirSyncMac: Timer fired. Reconnecting...")
                self?.connect()
            }
        }
    }

    private func receiveData() {
        guard isActuallyConnected, let connection = connection else {
            print("AirSyncMac: Cannot receive data, not connected or connection nil.")
            return
        }
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1024 * 1024) { [weak self] (data, context, isComplete, error) in // Increased max length for large icons
            guard let self = self else { return }

            if let error = error {
                print("AirSyncMac: Receive error: \(error.localizedDescription).")
                return
            }
            if isComplete {
                print("AirSyncMac: Receive completed. Server closed connection.")
                self.isActuallyConnected = false
                DispatchQueue.main.async { ClientManager.shared.connectionUpdateHandler(.cancelled) }
                return
            }
            if let receivedData = data, !receivedData.isEmpty {
                self.buffer.append(receivedData)
                self.processBuffer()
            }
            if self.isActuallyConnected {
                self.receiveData()
            }
        }
    }

    private func processBuffer() {
        while let newlineRange = buffer.range(of: Data("\n".utf8)) {
            let messageData = buffer.subdata(in: 0..<newlineRange.lowerBound)
            buffer.removeSubrange(0..<newlineRange.upperBound)
            if let messageString = String(data: messageData, encoding: .utf8), !messageString.isEmpty {
                handleMessage(messageString)
            }
        }
    }

    private func handleMessage(_ messageString: String) {
        // This part seems to be working correctly based on your log
        print("AirSyncMac: Handling message from Android: \(messageString.prefix(200))...") // Log only prefix for brevity
        guard let jsonData = messageString.data(using: .utf8) else {
            print("AirSyncMac: Failed to convert message string to data: \(messageString.prefix(200))")
            return
        }
        let decoder = JSONDecoder()
        do {
            let typePeek = try decoder.decode(MessageTypePeek.self, from: jsonData)
            if typePeek.type == "clipboard" {
                // Explicitly a clipboard message from Android
                do {
                    let clipboardContent = try decoder.decode(ClipboardData.self, from: jsonData)
                    if let textToCopy = clipboardContent.text {
                        DispatchQueue.main.async {
                            self.updateClipboard(text: textToCopy)
                            self.showSystemNotification(title: "AirSync", body: "Clipboard updated from Android.")
                            print("AirSyncMac: Successfully processed clipboard message from Android.")
                        }
                    } else {
                        print("AirSyncMac: Clipboard message from Android (type: clipboard) had no text.")
                    }
                } catch {
                     print("AirSyncMac: Failed to decode clipboard message (type was 'clipboard'): \(error.localizedDescription). Message: \(messageString)")
                }
            } else { // Assumed notification
                print("AirSyncMac: Assuming notification type (type was '\(typePeek.type ?? "nil")').")
                do {
                    let notification = try decoder.decode(NotificationData.self, from: jsonData)
                    DispatchQueue.main.async { // Ensure UI related notification code is on main
                        self.showNotification(notification)
                        print("AirSyncMac: Successfully decoded NotificationData. App: \(notification.app ?? "N/A")")
                    }
                } catch {
                    print("AirSyncMac: Failed to decode NotificationData (type '\(typePeek.type ?? "nil")'): \(error.localizedDescription).")
                }
            }
        } catch { // Initial type peek failed, try direct NotificationData decode
             print("AirSyncMac: Initial type peek failed. Assuming NotificationData. Error: \(error.localizedDescription).")
            do {
                let notification = try decoder.decode(NotificationData.self, from: jsonData)
                DispatchQueue.main.async {
                    self.showNotification(notification)
                    print("AirSyncMac: Successfully decoded NotificationData (direct fallback). App: \(notification.app ?? "N/A")")
                }
            } catch let finalError {
                print("AirSyncMac: Failed to decode as any known type (final fallback). Error: \(finalError.localizedDescription).")
            }
        }
    }


    private func showNotification(_ data: NotificationData) {
            print("AirSyncMac: showNotification called with App: \(data.app ?? "N/A"), Title: \(data.title ?? "N/A")")
            let content = UNMutableNotificationContent()
            
            let appName = data.app?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let originalTitle = data.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Notification"
            let deviceName = ClientManager.shared.androidDeviceName // Get the configured device name
            
            content.title = !appName.isEmpty ? "\(appName): \(originalTitle)" : originalTitle
            content.subtitle = "From \(deviceName)" // Use device name in subtitle
            content.body = data.text ?? ""
            content.sound = .default
            
            var notificationAttachments: [UNNotificationAttachment] = []
            if let iconBase64 = data.iconBase64String, !iconBase64.isEmpty {
                if let iconData = Data(base64Encoded: iconBase64, options: .ignoreUnknownCharacters) {
                    if let image = NSImage(data: iconData) {
                        let imageIdentifier = UUID().uuidString
                        let tempDirectory = FileManager.default.temporaryDirectory
                        let tempFilename = "airsync_icon_\(imageIdentifier).png"
                        let tempURL = tempDirectory.appendingPathComponent(tempFilename)
                        do {
                            guard let tiffRepresentation = image.tiffRepresentation,
                                  let bitmapImageRep = NSBitmapImageRep(data: tiffRepresentation),
                                  let pngData = bitmapImageRep.representation(using: .png, properties: [:]) else {
                                self.submitNotificationRequest(content: content, identifierSuffix: "-noIconConvFail")
                                return
                            }
                            try pngData.write(to: tempURL)
                            let attachment = try UNNotificationAttachment(identifier: imageIdentifier, url: tempURL, options: nil)
                            notificationAttachments.append(attachment)
                        } catch {
                            print("AirSyncMac: ERROR creating or writing attachment: \(error.localizedDescription)")
                            self.submitNotificationRequest(content: content, identifierSuffix: "-noIconAttachFail")
                            return
                        }
                    } else {
                        self.submitNotificationRequest(content: content, identifierSuffix: "-noIconNSImageFail")
                        return
                    }
                } else {
                    self.submitNotificationRequest(content: content, identifierSuffix: "-noIconBase64Fail")
                    return
                }
            }
            
            content.attachments = notificationAttachments
            self.submitNotificationRequest(content: content, identifierSuffix: "-withOrWithoutIcon")
        }

        private func submitNotificationRequest(content: UNMutableNotificationContent, identifierSuffix: String = "") {
            let requestIdentifier = UUID().uuidString + identifierSuffix
            let request = UNNotificationRequest(identifier: requestIdentifier, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("AirSyncMac: CRITICAL ERROR adding notification (ID: \(requestIdentifier)): \(error.localizedDescription)")
                } else {
                    print("AirSyncMac: Notification request (ID: \(requestIdentifier)) successfully added.")
                }
            }
        }
    
    private func updateClipboard(text: String?) {
            guard let text = text else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            let deviceName = ClientManager.shared.androidDeviceName
            self.showSystemNotification(title: "AirSync", body: "Clipboard updated from \(deviceName).") // Include device name
            print("AirSyncMac: Mac clipboard updated.")
        }
        
        private func showSystemNotification(title: String, body: String) {
            DispatchQueue.main.async {
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = .default
                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                UNUserNotificationCenter.current().add(request)
            }
        }

    func send(string: String) {
                guard isActuallyConnected, let connection = connection else {
                    print("AirSyncMac: Not connected. Cannot send string: \(string.prefix(30))")
                    return
                }
                let fullMessage = string + "\n"
                guard let dataToSend = fullMessage.data(using: .utf8) else {
                    print("AirSyncMac: Error encoding string for sending.")
                    return
                }
                connection.send(content: dataToSend, completion: .contentProcessed { error in
                    DispatchQueue.main.async {
                        if let error = error { print("AirSyncMac: Send error: \(error.localizedDescription)") }
                    }
                })
            }

        func disconnect() {
            print("AirSyncMac: Disconnect called.")
            reconnectTimer?.invalidate()
            connection?.cancel()
            isActuallyConnected = false
        }
    }
