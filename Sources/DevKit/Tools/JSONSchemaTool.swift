import SwiftUI
import DevKitCore

struct JSONSchemaTool: Tool {
    let id = "json-schema"
    let name = "JSON Schema"
    let summary = "Check a document against type, required, enum, and length rules"
    let symbol = "checkmark.seal"
    let category = ToolCategory.inspection
    func makeView() -> AnyView { AnyView(JSONSchemaToolView()) }
}

struct JSONSchemaToolView: View {
    @EnvironmentObject private var model: AppModel
    @State private var schema = #"{"type":"object","required":["name"],"properties":{"name":{"type":"string","minLength":1}}}"#
    @State private var restored = false

    var body: some View {
        let current = schema
        TextToolView(
            toolID: "json-schema",
            sample: #"{"name":""}"#,
            runToken: current,
            canSwap: false,
            transform: { JSONSchemaCheck.validate(document: $0, schema: current) }
        ) {
            TextEditor(text: $schema)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, minHeight: 72, maxHeight: 110)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
        }
        .onAppear {
            guard !restored else { return }
            restored = true
            if let saved = model.loadOptionsObject(for: "json-schema")["schema"] as? String, !saved.isEmpty {
                schema = saved
            }
        }
        .onSample {
            schema = #"{"type":"object","required":["name"],"properties":{"name":{"type":"string","minLength":1}}}"#
        }
        .onChange(of: schema) { _, newValue in
            model.saveOptionsObject(["schema": newValue], for: "json-schema")
        }
    }
}
