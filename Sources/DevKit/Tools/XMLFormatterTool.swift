import SwiftUI
import DevKitCore

struct XMLFormatterTool: Tool {
    let id = "xml-formatter"
    let name = "XML Formatter"
    let summary = "Prettify, minify, and validate XML"
    let symbol = "chevron.left.forwardslash.chevron.right"
    let category = ToolCategory.formatters
    func makeView() -> AnyView { AnyView(XMLFormatterToolView()) }
}

struct XMLFormatterToolView: View {
    @EnvironmentObject private var model: AppModel
    @State private var mode: XMLFormatter.Mode = .prettify
    @State private var restored = false

    var body: some View {
        let chosen = mode
        TextToolView(
            toolID: "xml-formatter",
            sample: "<root><item id=\"1\">Hello</item><item id=\"2\">World</item></root>",
            runToken: chosen.rawValue,
            transform: { XMLFormatter.format($0, mode: chosen) }
        ) {
            Picker("Mode", selection: $mode) {
                Text("Prettify").tag(XMLFormatter.Mode.prettify)
                Text("Minify").tag(XMLFormatter.Mode.minify)
                Text("Validate").tag(XMLFormatter.Mode.validate)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)
        }
        .onAppear {
            guard !restored else { return }
            restored = true
            if let value = model.loadOptionsObject(for: "xml-formatter")["mode"] as? String,
               let parsed = XMLFormatter.Mode(rawValue: value) { mode = parsed }
        }
        .onChange(of: mode) { _, _ in
            model.saveOptionsObject(["mode": mode.rawValue], for: "xml-formatter")
        }
    }
}
