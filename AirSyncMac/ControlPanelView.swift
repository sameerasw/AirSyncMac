import SwiftUI
import AppKit

struct ControlPanelView: View {
    @StateObject private var clientManager = ClientManager.shared
    
    @State private var editHost: String = ""
    @State private var editPort: String = "" // App communication port
    @State private var editScrcpyPort: String = "" // New: Scrcpy/ADB port
    @State private var editDeviceName: String = ""

    @State private var isMacClipboardEmpty: Bool = true

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .edgesIgnoringSafeArea(.all)

            VStack(alignment: .leading, spacing: 20) {
                Text("Device Settings")
                    .font(.title2)
                    .bold()

                VStack(spacing: 12) {
                    TextField("Android Device Name", text: $editDeviceName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(saveSettingsAndAttemptConnect)

                    HStack(spacing: 12) {
                        TextField("Android IP Address", text: $editHost)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(saveSettingsAndAttemptConnect)
                        
                        TextField("App Port", text: $editPort) // Clarified label
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .onSubmit(saveSettingsAndAttemptConnect)
                    }
                    // New TextField for Scrcpy/ADB Port
                    TextField("Scrcpy/ADB Port (e.g., 5555)", text: $editScrcpyPort)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(saveSettingsAndAttemptConnect)
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
                    .disabled(editHost.isEmpty || editPort.isEmpty || UInt16(editPort) == nil || editScrcpyPort.isEmpty || UInt16(editScrcpyPort) == nil) // Added scrcpy port validation to disabled state

                    if clientManager.isConnectingOrConnected {
                        Button(action: { clientManager.disconnect() }) {
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
                    .padding(.bottom, 5)

                Divider()

                Text("Send to Android Clipboard")
                    .font(.title3)
                    .bold()

                TextEditor(text: $clientManager.textToSendToAndroidClipboard)
                    .frame(height: 100)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.textBackgroundColor)))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))

                HStack {
                    Button(action: {
                        clientManager.sendClipboardToAndroid()
                    }) {
                        Label("Send Text Above", systemImage: "paperplane.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!clientManager.isConnected || clientManager.textToSendToAndroidClipboard.isEmpty)

                    Spacer()

                    Button(action: {
                        clientManager.sendMacClipboardToAndroid()
                    }) {
                        Label("Send Current Clipboard", systemImage: "doc.on.clipboard")
                    }
                    .disabled(!clientManager.isConnected || isMacClipboardEmpty)
                }
                .padding(.top, 6)

                Spacer()
            }
            .padding(24)
        }
        .onAppear {
            editHost = clientManager.currentHost
            editPort = String(clientManager.currentPort)
            editScrcpyPort = String(clientManager.currentScrcpyPort) // New
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
        
        guard let scrcpyPortNumber = UInt16(editScrcpyPort), scrcpyPortNumber > 0 else { // New validation
            clientManager.connectionStatus = "Error: Invalid Scrcpy/ADB Port"
            return
        }

        let deviceNameToSave = editDeviceName.isEmpty ? "Phone" : editDeviceName

        clientManager.updateSettings(
            host: editHost,
            port: appPortNumber,
            deviceName: deviceNameToSave,
            scrcpyPort: scrcpyPortNumber // New
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
}

struct ConnectionStatusIndicator: View {
    let status: String

    var color: Color {
        switch status {
        case "Connected":
            return .green
        case let s where s.starts(with: "Connecting") || s.starts(with: "Preparing") || s.starts(with: "Setup") || s.starts(with: "Waiting"):
            return .orange
        default:
            return .red
        }
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 12, height: 12)
            .shadow(color: color.opacity(0.6), radius: 1)
            .padding(.trailing, 6)
    }
}

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    var state: NSVisualEffectView.State = .active

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

#if DEBUG
struct ControlPanelView_Previews: PreviewProvider {
    static var previews: some View {
        ControlPanelView()
            .frame(width: 420, height: 550) // Adjusted height slightly for the new field
            .preferredColorScheme(.dark)
    }
}
#endif
