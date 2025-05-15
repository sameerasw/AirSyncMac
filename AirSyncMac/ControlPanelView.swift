// AirSyncMac/AirSyncMac/ControlPanelView.swift
import SwiftUI

struct ControlPanelView: View {
    @StateObject private var clientManager = ClientManager.shared
    
    // Local states for text fields to avoid direct modification of clientManager's host/port
    // before explicitly connecting with new values.
    @State private var editHost: String = ""
    @State private var editPort: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Connection Settings")
                .font(.headline)

            HStack {
                TextField("Android IP Address", text: $editHost)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                TextField("Port", text: $editPort)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 70)
                
                ConnectionStatusIndicator(status: clientManager.connectionStatus)
                    .padding(.leading, 5)
            }
            
            HStack(spacing: 10) {
                Button(action: connectClient) {
                    Text("Connect")
                        .frame(minWidth: 80)
                }
                .disabled(clientManager.isConnectingOrConnected) // Disable if connecting or connected
                
                Button(action: disconnectClient) {
                    Text("Disconnect")
                        .frame(minWidth: 80)
                }
                .disabled(!clientManager.isConnectingOrConnected && !clientManager.isConnected) // Disable if not connected and not attempting
            }
            
            Text("Status: \(clientManager.connectionStatus)")
                .font(.caption)
                .foregroundColor(.gray)
                .lineLimit(2)
                .frame(height: 30) // Ensure space for two lines of status
                .padding(.bottom, 5)

            Divider()

            Text("Send to Android Clipboard")
                .font(.headline)
            
            TextEditor(text: $clientManager.textToSendToAndroidClipboard)
                .frame(height: 80)
                .border(Color.gray.opacity(0.3), width: 1)
                .clipShape(RoundedRectangle(cornerRadius: 4)) // So border follows rounding

            Button(action: sendClipboardText) {
                Text("Send to Android")
                    .frame(minWidth: 120)
            }
            .disabled(!clientManager.isConnected || clientManager.textToSendToAndroidClipboard.isEmpty)

            Spacer() // Push content to the top
        }
        .padding()
        .onAppear {
            // Initialize editHost and editPort from ClientManager's persisted values
            editHost = clientManager.currentHost
            editPort = String(clientManager.currentPort)
        }
        // Optional: Add a background to make it look more like a typical app window
        // .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func connectClient() {
        // Validate port input
        guard let portNumber = UInt16(editPort), portNumber > 0 else {
            clientManager.connectionStatus = "Invalid Port Number"
            return
        }
        // Update ClientManager with potentially new host/port from text fields
        clientManager.updateConnection(host: editHost, port: portNumber)
        clientManager.connect()
    }
    
    private func disconnectClient() {
        clientManager.disconnect()
    }

    private func sendClipboardText() {
        clientManager.sendClipboardToAndroid()
        // Optionally clear the text field after sending:
        // clientManager.textToSendToAndroidClipboard = ""
    }
}

struct ConnectionStatusIndicator: View {
    let status: String // Pass the full status string
    
    var color: Color {
        switch status {
        case "Connected":
            return .green
        case "Connecting...", "Preparing...", "Setup...", "Waiting...":
            return .orange // Indicate an attempt or wait
        default: // Disconnected, Failed, Error
            return .red
        }
    }
    
    var body: some View {
        Circle()
            .frame(width: 15, height: 15)
            .foregroundColor(color)
            .shadow(color: color.opacity(0.7), radius: 2)
    }
}

#if DEBUG
struct ControlPanelView_Previews: PreviewProvider {
    static var previews: some View {
        ControlPanelView()
            .environmentObject(ClientManager.shared) // For preview
            .frame(width: 400, height: 380) // Simulate typical window size
    }
}
#endif
