import SwiftUI
import DevKitCore

struct JSONFormatterTool: Tool {
    let id = "json-formatter"
    let name = "JSON Formatter"
    let summary = "Beautify, minify, validate, and sort JSON keys"
    let symbol = "curlybraces"
    let category = ToolCategory.formatters

    func makeView() -> AnyView { AnyView(JSONFormatterToolView()) }
}

struct JSONFormatterToolView: View {
    @EnvironmentObject private var model: AppModel
    @State private var mode: JSONFormatter.Mode = .beautify
    @State private var indent: JSONFormatter.Indent = .two
    @State private var sortKeys = false
    @State private var restored = false

    var body: some View {
        let chosenMode = mode
        let chosenIndent = indent
        let chosenSort = sortKeys
        TextToolView(
            toolID: "json-formatter",
            sample: #"{"b":1,"a":[true,null,"hi"]}"#,
            runToken: "\(chosenMode.rawValue)|\(chosenIndent.rawValue)|\(chosenSort)",
            transform: { text in
                JSONFormatter.format(text, mode: chosenMode, indent: chosenIndent, sortKeys: chosenSort)
            }
        ) {
            HStack(spacing: 12) {
                Picker("Mode", selection: $mode) {
                    Text("Beautify").tag(JSONFormatter.Mode.beautify)
                    Text("Minify").tag(JSONFormatter.Mode.minify)
                    Text("Validate").tag(JSONFormatter.Mode.validate)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 280)
                Picker("Indent", selection: $indent) {
                    Text("2 spaces").tag(JSONFormatter.Indent.two)
                    Text("4 spaces").tag(JSONFormatter.Indent.four)
                    Text("Tab").tag(JSONFormatter.Indent.tab)
                }
                .frame(maxWidth: 180)
                .disabled(mode != .beautify)
                Toggle("Sort keys", isOn: $sortKeys)
                    .disabled(mode == .validate)
                Spacer()
            }
        }
        .onAppear(perform: restore)
        .onChange(of: mode) { _, _ in persist() }
        .onChange(of: indent) { _, _ in persist() }
        .onChange(of: sortKeys) { _, _ in persist() }
    }

    private func restore() {
        guard !restored else { return }
        restored = true
        guard let raw = model.blob(for: "json-formatter").options,
              let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        if let value = object["mode"] as? String, let parsed = JSONFormatter.Mode(rawValue: value) {
            mode = parsed
        }
        if let value = object["indent"] as? String, let parsed = JSONFormatter.Indent(rawValue: value) {
            indent = parsed
        }
        if let value = object["sortKeys"] as? Bool {
            sortKeys = value
        }
    }

    private func persist() {
        let object: [String: Any] = [
            "mode": mode.rawValue,
            "indent": indent.rawValue,
            "sortKeys": sortKeys,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let json = String(data: data, encoding: .utf8) else { return }
        model.setOptions(json, for: "json-formatter")
    }
}
