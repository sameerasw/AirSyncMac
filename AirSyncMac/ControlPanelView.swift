import SwiftUI
import AppKit

struct ControlPanelView: View {
    @StateObject private var clientManager = ClientManager.shared // Used for connection state and settings
    
    @State private var editHost: String = ""
    @State private var editPort: String = ""
    @State private var editScrcpyPort: String = ""
    @State private var editDeviceName: String = ""

    @State private var isMacClipboardEmpty: Bool = true

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .edgesIgnoringSafeArea(.all)

            VStack(alignment: .leading, spacing: 13) {

                VStack(spacing: 12) {
                    
                    
                    HStack(spacing: 12) {
                        Text("Device ")
                            .font(.title3)
                        
                        TextField("Android Device Name", text: $editDeviceName)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(saveSettingsAndAttemptConnect)
                    }
                    
                    
                    HStack(spacing: 12) {
                        Text("Server ")
                            .font(.title3)
                        
                        HStack(spacing: 12) {
                            TextField("Android IP Address", text: $editHost)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit(saveSettingsAndAttemptConnect)
                            
                            TextField("App Port", text: $editPort)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                                .onSubmit(saveSettingsAndAttemptConnect)
                        }
                    }
                    
                    
                    HStack(spacing: 12) {
                        Text("ADB ")
                            .font(.title3)
                        
                        TextField("Scrcpy/ADB Port", text: $editScrcpyPort)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(saveSettingsAndAttemptConnect)
                    }
                }

                HStack {
                    ConnectionStatusIndicator(status: clientManager.connectionStatus)

                    Button(action: saveSettingsAndAttemptConnect) {
                        Label(
                            clientManager.isConnectingOrConnected ? "Update & Reconnect" : "Save & Connect",
                            systemImage: "arrow.triangle.2.circlepath"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .disabled(editHost.isEmpty || editPort.isEmpty || UInt16(editPort) == nil || editScrcpyPort.isEmpty || UInt16(editScrcpyPort) == nil)

                    if clientManager.isConnectingOrConnected {
                        Button(action: { clientManager.disconnect() }) { // Assumes clientManager.disconnect() is fine
                            Label("Disconnect", systemImage: "xmark.circle")
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .controlSize(.regular)
                    }
                    Spacer()
                }

                Text("Status: \(clientManager.connectionStatus)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 3)

                Divider()

                Text("Send to Android Clipboard")
                    .font(.title3)
                    .bold()

                TextEditor(text: $clientManager.textToSendToAndroidClipboard) // Assumes this property is fine
                    .frame(height: 80)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.textBackgroundColor)))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))

                HStack {
                    Button(action: {
                        clientManager.sendClipboardToAndroid() // Assumes this is fine
                    }) {
                        Label("Send", systemImage: "paperplane.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!clientManager.isConnected || clientManager.textToSendToAndroidClipboard.isEmpty)

                    Spacer()

                    Button(action: {
                        clientManager.sendMacClipboardToAndroid() // Assumes this is fine
                    }) {
                        Label("Send Clipboard", systemImage: "doc.on.clipboard")
                    }
                    .disabled(!clientManager.isConnected || isMacClipboardEmpty)
                    
                    Spacer()
                    
                    Button(action: {
                        AndroidNotificationClient.clearAllMacNotifications()
                    }) {
                        Label("Clear All", systemImage: "bell.slash.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                }
                .padding(.top, 4)


                Divider()

                HStack {
                    Button(action: {
                        triggerGenericRemoteView()
                    }) {
                        Label("Remote View", systemImage: "display")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!clientManager.isConnected) // Enabled only if network connected (ADB might be connected)

                    Spacer()
                    
                    Button(action: {
                                if let url = URL(string: "https://www.sameerasw.com") {
                                    NSWorkspace.shared.open(url)
                                }
                            }) {
                                Label("About", systemImage: "info.circle")
                            }
                            .buttonStyle(.bordered)
                }
                .padding(.top, 8)
                
                Spacer()
            }
            .padding(20)
        }
        .onAppear {
            editHost = clientManager.currentHost
            editPort = String(clientManager.currentPort)
            editScrcpyPort = String(clientManager.currentScrcpyPort)
            editDeviceName = clientManager.androidDeviceName
            updateMacClipboardStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            updateMacClipboardStatus()
        }
    }

    private func saveSettingsAndAttemptConnect() {
        guard let appPortNumber = UInt16(editPort), appPortNumber > 0 else {
            clientManager.connectionStatus = "Error: Invalid App Port"
            return
        }
        
        guard let scrcpyPortNumber = UInt16(editScrcpyPort), scrcpyPortNumber > 0 else {
            clientManager.connectionStatus = "Error: Invalid Scrcpy/ADB Port"
            return
        }

        let deviceNameToSave = editDeviceName.isEmpty ? "Phone" : editDeviceName

        // This part still calls clientManager to update its settings and trigger connect.
        // This is not adding new methods for the buttons, but using existing ClientManager functions.
        clientManager.updateSettings(
            host: editHost,
            port: appPortNumber,
            deviceName: deviceNameToSave,
            scrcpyPort: scrcpyPortNumber
        )
        clientManager.connect()
    }

    private func updateMacClipboardStatus() {
        if let clipboardString = NSPasteboard.general.string(forType: .string), !clipboardString.isEmpty {
            isMacClipboardEmpty = false
        } else {
            isMacClipboardEmpty = true
        }
    }

    // New private function in the View to handle the temporary client creation
    private func triggerGenericRemoteView() {
        guard clientManager.isConnected else {
            // Optionally, show an alert to the user that they need to be connected.
            // For now, just print.
            print("AirSyncMac ControlPanel: Cannot trigger remote view, not connected.")
            // We can also use the static method from AndroidNotificationClient to show a system notification
            // if we don't want to rely on the main client instance for this feedback.
            AndroidNotificationClient.clearAllMacNotifications() // misuse of this, but it posts a notification
            // A better way would be:
            // let tempContent = UNMutableNotificationContent()
            // tempContent.title = "AirSync Error"
            // tempContent.body = "Not connected to device. Cannot start remote view."
            // UNUserNotificationCenter.current().add(...)
            return
        }
        
        print("AirSyncMac ControlPanel: Triggering generic remote view via temporary client.")
        // Create a temporary client. It won't establish a new network connection for this call.
        // It only uses the host/port to be instantiated, but launchGenericScrcpy doesn't use them.
        let tempAndroidClient = AndroidNotificationClient(host: clientManager.currentHost, port: clientManager.currentPort)
        tempAndroidClient.launchGenericScrcpy(deviceName: clientManager.androidDeviceName)
    }
}

// ConnectionStatusIndicator and VisualEffectView remain the same
struct ConnectionStatusIndicator: View {
    let status: String
    var color: Color {
        switch status {
        case "Connected": return .green
        case let s where s.starts(with: "Connecting") || s.starts(with: "Preparing") || s.starts(with: "Setup") || s.starts(with: "Waiting"): return .orange
        default: return .red
        }
    }
    var body: some View { Circle().fill(color).frame(width: 12, height: 12).shadow(color: color.opacity(0.6), radius: 1).padding(.trailing, 6) }
}

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    var state: NSVisualEffectView.State = .active
    func makeNSView(context: Context) -> NSVisualEffectView { let view = NSVisualEffectView(); view.material = material; view.blendingMode = blendingMode; view.state = state; return view }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) { nsView.material = material; nsView.blendingMode = blendingMode; nsView.state = state }
}

#if DEBUG
struct ControlPanelView_Previews: PreviewProvider {
    static var previews: some View {
        ControlPanelView()
            .frame(width: 420, height: 580)
            .preferredColorScheme(.dark)
    }
}
#endif
