import SwiftUI
import DevKitCore

struct JSONYAMLTool: Tool {
    let id = "json-yaml"
    let name = "JSON ↔ YAML"
    let summary = "Convert between JSON and YAML"
    let symbol = "arrow.left.arrow.right"
    let category = ToolCategory.converters
    func makeView() -> AnyView { AnyView(JSONYAMLToolView()) }
}

private enum JSONYAMLDirection: String {
    case jsonToYAML, yamlToJSON
}

struct JSONYAMLToolView: View {
    @EnvironmentObject private var model: AppModel
    @State private var direction: JSONYAMLDirection = .jsonToYAML
    @State private var restored = false

    var body: some View {
        let chosen = direction
        TextToolView(
            toolID: "json-yaml",
            sample: #"{"name":"Ada","ok":true,"n":2}"#,
            runToken: chosen.rawValue,
            transform: { text in
                chosen == .jsonToYAML ? YAMLJSON.jsonToYAML(text) : YAMLJSON.yamlToJSON(text)
            }
        ) {
            Picker("Direction", selection: $direction) {
                Text("JSON to YAML").tag(JSONYAMLDirection.jsonToYAML)
                Text("YAML to JSON").tag(JSONYAMLDirection.yamlToJSON)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)
        }
        .onAppear {
            guard !restored else { return }
            restored = true
            if let value = model.loadOptionsObject(for: "json-yaml")["direction"] as? String,
               let parsed = JSONYAMLDirection(rawValue: value) { direction = parsed }
        }
        .onChange(of: direction) { _, _ in
            model.saveOptionsObject(["direction": direction.rawValue], for: "json-yaml")
        }
    }
}
