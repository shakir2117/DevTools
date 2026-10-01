import SwiftUI

struct WindowFrameAutosave: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            view.window?.setFrameAutosaveName("DevKitMain")
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if nsView.window?.frameAutosaveName != "DevKitMain" {
            nsView.window?.setFrameAutosaveName("DevKitMain")
        }
    }
}
