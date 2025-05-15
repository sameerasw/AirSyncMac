import SwiftUI

struct WindowConfigurator: View {
    var body: some View {
        Color.clear
            .background(WindowAccessor { window in
                guard let window = window else { return }

                window.titlebarAppearsTransparent = true
                window.isOpaque = false
                window.backgroundColor = .clear
                window.styleMask.insert(.fullSizeContentView)
            })
    }
}

struct WindowAccessor: NSViewRepresentable {
    var callback: (NSWindow?) -> ()

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.callback(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
