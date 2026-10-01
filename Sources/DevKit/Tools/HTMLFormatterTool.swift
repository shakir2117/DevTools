import SwiftUI
import DevKitCore

struct HTMLMarkupTool: Tool {
    let id = "html-formatter"
    let name = "HTML Formatter"
    let summary = "Beautify and minify HTML"
    let symbol = "doc.text"
    let category = ToolCategory.formatters
    func makeView() -> AnyView { AnyView(HTMLMarkupToolView()) }
}

struct HTMLMarkupToolView: View {
    @EnvironmentObject private var model: AppModel
    @State private var mode: HTMLMarkup.Mode = .beautify
    @State private var restored = false

    var body: some View {
        let chosen = mode
        TextToolView(
            toolID: "html-formatter",
            sample: "<div><p>Hello <strong>DevKit</strong></p></div>",
            runToken: chosen.rawValue,
            canSwap: true,
            transform: { HTMLMarkup.format($0, mode: chosen) }
        ) {
            Picker("Mode", selection: $mode) {
                Text("Beautify").tag(HTMLMarkup.Mode.beautify)
                Text("Minify").tag(HTMLMarkup.Mode.minify)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 240)
        }
        .onAppear(perform: restore)
        .onChange(of: mode) { _, _ in persist() }
    }

    private func restore() {
        guard !restored else { return }
        restored = true
        if let value = model.loadOptionsObject(for: "html-formatter")["mode"] as? String,
           let parsed = HTMLMarkup.Mode(rawValue: value) {
            mode = parsed
        }
    }

    private func persist() {
        model.saveOptionsObject(["mode": mode.rawValue], for: "html-formatter")
    }
}
