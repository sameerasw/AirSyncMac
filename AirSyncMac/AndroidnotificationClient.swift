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
    let packageName: String?
    let iconBase64String: String?

    enum CodingKeys: String, CodingKey {
        case app = "appName"
        case title, text, packageName
        case iconBase64String = "icon_base64"
    }
}

struct ClipboardData: Codable {
    let text: String?
}

struct MessageTypePeek: Decodable {
    let type: String?
}

class AndroidNotificationClient: NSObject, UNUserNotificationCenterDelegate {
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.airsync.notification.client", qos: .userInitiated)
    private var buffer = Data()
    private var isActuallyConnected = false
    private var reconnectTimer: Timer?

    let host: NWEndpoint.Host
    let port: NWEndpoint.Port // App communication port

    static let viewActionIdentifier = "VIEW_ACTION"
    static let notificationCategoryIdentifier = "ANDROID_NOTIFICATION_CATEGORY"

    init(host: String, port: UInt16) {
        self.host = NWEndpoint.Host(host)
        self.port = NWEndpoint.Port(integerLiteral: port)
        super.init()
        UNUserNotificationCenter.current().delegate = self
        print("AirSyncMac: AndroidNotificationClient initialized for \(host):\(port)")
    }

    static func registerNotificationCategories() {
            let viewAction = UNNotificationAction(identifier: viewActionIdentifier,
                                                  title: "View",
                                                  options: [.foreground])

            let category = UNNotificationCategory(identifier: notificationCategoryIdentifier,
                                                  actions: [viewAction],
                                                  intentIdentifiers: [],
                                                  options: .customDismissAction)

            UNUserNotificationCenter.current().setNotificationCategories([category])
            print("AirSyncMac: Notification categories registered.")
        }

        func connect() {
            print("AirSyncMac: Attempting to connect to \(host.debugDescription):\(port.debugDescription)...")
            let params = NWParameters.tcp
            connection = NWConnection(host: host, port: port, using: params)
            
            connection?.stateUpdateHandler = { [weak self] newState in
                guard let self = self else { return }
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
                    self.isActuallyConnected = false
                    self.scheduleReconnect()
                case .setup:
                    print("AirSyncMac: Connection state SETUP.")
                    self.isActuallyConnected = false
                case .preparing:
                    print("AirSyncMac: Connection state PREPARING.")
                    self.isActuallyConnected = false
                case .cancelled:
                    print("AirSyncMac: Connection state CANCELLED.")
                    self.isActuallyConnected = false
                    self.reconnectTimer?.invalidate()
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
            
            let deviceName = ClientManager.shared.androidDeviceName
            let currentIpAddress = ClientManager.shared.currentHost
            let scrcpyAdbPort = ClientManager.shared.currentScrcpyPort // MODIFIED: Get scrcpy/ADB port

            DispatchQueue.main.async {
                self.showSystemNotification(title: "AirSync", body: "Network connected to \(deviceName) (\(currentIpAddress)).")
            }

            // MODIFIED: Use the configured scrcpy/ADB port
            let adbCommand = "adb connect \(currentIpAddress):\(scrcpyAdbPort)"
            print("AirSyncMac: Attempting auto ADB connect: \(adbCommand)")

            launchShellCommand(command: adbCommand, wait: true) { [weak self] adbSuccess, adbOutput, adbError in
                DispatchQueue.main.async {
                    guard let strongSelf = self else { return }
                    let adbTargetString = "\(currentIpAddress):\(scrcpyAdbPort)" // For checking output more accurately
                    if adbSuccess && (adbOutput.contains("connected to \(adbTargetString)") || adbOutput.contains("already connected to \(adbTargetString)") || adbOutput.contains("connected to \(currentIpAddress)")){ // Last condition is a bit more general
                        print("AirSyncMac: Auto ADB connect successful. Output: \(adbOutput)")
                        strongSelf.showSystemNotification(title: "AirSync", body: "ADB connected to \(deviceName) (\(adbTargetString)).")
                    } else {
                        print("AirSyncMac: Auto ADB connect FAILED. ADB Success: \(adbSuccess), Output: '\(adbOutput)', Error: '\(adbError)'")
                        strongSelf.showSystemNotification(title: "AirSync Warning", body: "ADB connection to \(adbTargetString) failed. 'View' functionality might not work. Error: \(adbError)")
                    }
                }
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
                if !isActuallyConnected {
                     DispatchQueue.main.async { ClientManager.shared.connectionUpdateHandler(.failed(NWError.posix(.ENOTCONN))) }
                     scheduleReconnect()
                }
                return
            }
            connection.receive(minimumIncompleteLength: 1, maximumLength: 1024 * 1024) { [weak self] (data, context, isComplete, error) in
                guard let self = self else { return }
                if let error = error {
                    print("AirSyncMac: Receive error: \(error.localizedDescription).")
                    self.isActuallyConnected = false
                    DispatchQueue.main.async { ClientManager.shared.connectionUpdateHandler(.failed(error)) }
                    self.scheduleReconnect()
                    return
                }
                if isComplete {
                    print("AirSyncMac: Receive completed. Server closed connection.")
                    self.isActuallyConnected = false
                    DispatchQueue.main.async { ClientManager.shared.connectionUpdateHandler(.cancelled) }
                    self.scheduleReconnect()
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
                } else if messageData.isEmpty && buffer.isEmpty {
                    break
                }
            }
        }
        
        private func handleMessage(_ messageString: String) {
            print("AirSyncMac: Handling message from Android: \(messageString.prefix(200))...")
            guard let jsonData = messageString.data(using: .utf8) else {
                print("AirSyncMac: Failed to convert message string to data: \(messageString.prefix(200))")
                return
            }
            let decoder = JSONDecoder()
            do {
                let typePeek = try decoder.decode(MessageTypePeek.self, from: jsonData)
                if typePeek.type == "clipboard" {
                    do {
                        let clipboardContent = try decoder.decode(ClipboardData.self, from: jsonData)
                        if let textToCopy = clipboardContent.text {
                            DispatchQueue.main.async {
                                self.updateClipboard(text: textToCopy)
                                print("AirSyncMac: Successfully processed clipboard message from Android.")
                            }
                        } else {
                            print("AirSyncMac: Clipboard message from Android (type: clipboard) had no text.")
                        }
                    } catch {
                         print("AirSyncMac: Failed to decode clipboard message (type was 'clipboard'): \(error.localizedDescription). Message: \(messageString)")
                    }
                } else {
                    print("AirSyncMac: Assuming notification type (type was '\(typePeek.type ?? "nil")').")
                    do {
                        let notification = try decoder.decode(NotificationData.self, from: jsonData)
                        DispatchQueue.main.async {
                            self.showNotification(notification)
                            print("AirSyncMac: Successfully decoded NotificationData. App: \(notification.app ?? "N/A")")
                        }
                    } catch {
                        print("AirSyncMac: Failed to decode NotificationData (type '\(typePeek.type ?? "nil")'): \(error.localizedDescription).")
                    }
                }
            } catch {
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
            let deviceName = ClientManager.shared.androidDeviceName
            
            content.title = !appName.isEmpty ? "\(appName): \(originalTitle)" : originalTitle
            content.subtitle = "From \(deviceName)"
            content.body = data.text ?? ""
            content.sound = .default

            content.categoryIdentifier = AndroidNotificationClient.notificationCategoryIdentifier
            var userInfo: [String: Any] = [:]
            if let packageName = data.packageName, !packageName.isEmpty {
                userInfo["packageName"] = packageName
            } else {
                print("AirSyncMac: PackageName is missing in notification data. 'View' action might not target a specific app.")
                userInfo["packageName"] = ""
            }
            userInfo["ipAddress"] = ClientManager.shared.currentHost
            content.userInfo = userInfo
            
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
                                print("AirSyncMac: Failed to convert icon to PNG.")
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
                         print("AirSyncMac: Could not create NSImage from icon data.")
                        self.submitNotificationRequest(content: content, identifierSuffix: "-noIconNSImageFail")
                        return
                    }
                } else {
                    print("AirSyncMac: Could not decode base64 icon string.")
                    self.submitNotificationRequest(content: content, identifierSuffix: "-noIconBase64Fail")
                    return
                }
            }
            
            content.attachments = notificationAttachments
            self.submitNotificationRequest(content: content, identifierSuffix: "-withViewAction")
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
            self.showSystemNotification(title: "AirSync", body: "Clipboard updated from \(deviceName).")
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
        
        // MARK: - UNUserNotificationCenterDelegate Methods -
        func userNotificationCenter(_ center: UNUserNotificationCenter,
                                  didReceive response: UNNotificationResponse,
                                  withCompletionHandler completionHandler: @escaping () -> Void) {
            let userInfo = response.notification.request.content.userInfo

            if response.actionIdentifier == AndroidNotificationClient.viewActionIdentifier {
                print("AirSyncMac: 'View' action tapped.")
                guard let packageName = userInfo["packageName"] as? String,
                      let ipAddress = userInfo["ipAddress"] as? String, !ipAddress.isEmpty else {
                    print("AirSyncMac: Error: Package name or IP address not found in notification userInfo for View action. IP: \(userInfo["ipAddress"] ?? "nil"), Package: \(userInfo["packageName"] ?? "nil")")
                    completionHandler()
                    return
                }

                print("AirSyncMac: Performing 'View' action for package '\(packageName.isEmpty ? "Screen Mirror" : packageName)' on device (assumed ADB connected to \(ipAddress)).")

                var scrcpyCommand = "/opt/scrcpy/scrcpy -m 800 -b 2M -e -S --video-codec=h265 --window-title='Sameera Pixel'"
                
                if !packageName.isEmpty {
                    scrcpyCommand += " --new-display=500x800 --start-app=\(packageName) --no-vd-system-decorations"
                }
                
                print("AirSyncMac: Launching scrcpy command: \(scrcpyCommand)")

                self.launchShellCommand(command: scrcpyCommand, wait: false) { [weak self] scrcpySuccess, scrcpyOutput, scrcpyError in
                    if scrcpySuccess {
                        print("AirSyncMac: scrcpy command launch initiated. Output/Log from launchShellCommand: \(scrcpyOutput)")
                    } else {
                        print("AirSyncMac: scrcpy command failed to initiate launch. Error: \(scrcpyError). Output: \(scrcpyOutput)")
                        self?.showSystemNotification(title: "AirSync Action Failed", body: "Failed to start scrcpy. Ensure ADB is connected and scrcpy is configured. Error: \(scrcpyError)")
                    }
                }
                completionHandler()
                return
            }
            completionHandler()
        }

        func userNotificationCenter(_ center: UNUserNotificationCenter,
                                  willPresent notification: UNNotification,
                                  withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
            if #available(macOS 11.0, *) {
                completionHandler([.banner, .list, .badge, .sound])
            } else {
                completionHandler([.alert, .badge, .sound])
            }
        }

        // launchShellCommand remains the same
        private func launchShellCommand(command: String, wait: Bool, completion: ((Bool, String, String) -> Void)? = nil) {
            DispatchQueue.global(qos: .userInitiated).async {
                let task = Process()
                let outputPipe = Pipe()
                let errorPipe = Pipe()

                task.standardOutput = outputPipe
                task.standardError = errorPipe
                
                task.arguments = ["-cl", command]
                task.executableURL = URL(fileURLWithPath: "/bin/zsh")

                var environment = ProcessInfo.processInfo.environment
                let commonToolPaths = ["/usr/local/bin", "/opt/homebrew/bin", "/usr/bin", "/bin", environment["PATH"] ?? ""].filter { !$0.isEmpty }.joined(separator: ":")
                environment["PATH"] = commonToolPaths
                task.environment = environment
                
                do {
                    try task.run()
                    print("AirSyncMac: Executing \(wait ? "and waiting for" : "detached") command: \(command) with PATH: \(environment["PATH"] ?? "Not set")")

                    if wait {
                        task.waitUntilExit()
                        
                        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                        let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        let errorOutput = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        
                        if task.terminationStatus == 0 {
                            completion?(true, output, errorOutput)
                        } else {
                            let combinedError = "\(errorOutput)\nExit status: \(task.terminationStatus)".trimmingCharacters(in: .whitespacesAndNewlines)
                            completion?(false, output, combinedError)
                        }
                    } else {
                        completion?(true, "Launched (detached): \(command)", "")
                    }
                } catch {
                    print("AirSyncMac: Failed to launch command '\(command)': \(error)")
                    completion?(false, "", error.localizedDescription)
                }
            }
        }
    }
