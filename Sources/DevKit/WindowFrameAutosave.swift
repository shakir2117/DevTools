import SwiftUI

struct WindowFrameAutosave: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async { Self.configure(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        Self.configure(nsView.window)
    }

    private static func configure(_ window: NSWindow?) {
        guard let window else { return }
        if window.frameAutosaveName != "DevKitMain" {
            window.setFrameAutosaveName("DevKitMain")
        }
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.isOpaque = false
        window.backgroundColor = .clear
        window.styleMask.insert(.fullSizeContentView)
        window.acceptsMouseMovedEvents = true
    }
}
