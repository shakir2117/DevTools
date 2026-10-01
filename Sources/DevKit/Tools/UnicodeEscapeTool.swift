import SwiftUI
import DevKitCore

struct UnicodeEscapeTool: Tool {
    let id = "unicode-escape"
    let name = "Unicode Escapes"
    let summary = "JSON \\u, HTML numeric, and URL percent encoding"
    let symbol = "textformat.abc"
    let category = ToolCategory.encoders
    func makeView() -> AnyView { AnyView(UnicodeEscapeToolView()) }
}

struct UnicodeEscapeToolView: View {
    @EnvironmentObject private var model: AppModel
    @State private var form: UnicodeEscape.Form = .json
    @State private var encode = true
    @State private var restored = false

    var body: some View {
        let chosen = form
        let encoding = encode
        TextToolView(
            toolID: "unicode-escape",
            sample: "A é",
            runToken: "\(chosen.rawValue)|\(encoding)",
            canSwap: false,
            transform: { encoding ? UnicodeEscape.encode($0, form: chosen) : UnicodeEscape.decode($0, form: chosen) }
        ) {
            FlowRow(spacing: 10, lineSpacing: 8) {
                Picker("Form", selection: $form) {
                    Text("JSON").tag(UnicodeEscape.Form.json)
                    Text("HTML").tag(UnicodeEscape.Form.html)
                    Text("URL").tag(UnicodeEscape.Form.url)
                }
                .frame(width: 140)
                Picker("Direction", selection: $encode) {
                    Text("Encode").tag(true)
                    Text("Decode").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
        }
        .onAppear {
            guard !restored else { return }
            restored = true
            let saved = model.loadOptionsObject(for: "unicode-escape")
            if let raw = saved["form"] as? String, let parsed = UnicodeEscape.Form(rawValue: raw) { form = parsed }
            if let value = saved["encode"] as? Bool { encode = value }
        }
        .onChange(of: form) { _, _ in persist() }
        .onChange(of: encode) { _, _ in persist() }
    }

    private func persist() {
        model.saveOptionsObject(["form": form.rawValue, "encode": encode], for: "unicode-escape")
    }
}
