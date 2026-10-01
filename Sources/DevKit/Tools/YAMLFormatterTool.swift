import SwiftUI
import DevKitCore

struct YAMLFormatterTool: Tool {
    let id = "yaml-formatter"
    let name = "YAML Formatter"
    let summary = "Prettify and validate YAML"
    let symbol = "list.bullet.indent"
    let category = ToolCategory.formatters
    func makeView() -> AnyView { AnyView(YAMLFormatterToolView()) }
}

struct YAMLFormatterToolView: View {
    @EnvironmentObject private var model: AppModel
    @State private var mode: YAMLFormatter.Mode = .prettify
    @State private var restored = false

    var body: some View {
        let chosen = mode
        TextToolView(
            toolID: "yaml-formatter",
            sample: "title: DevKit\nitems:\n- one\n- two\n",
            runToken: chosen.rawValue,
            transform: { YAMLFormatter.format($0, mode: chosen) }
        ) {
            Picker("Mode", selection: $mode) {
                Text("Prettify").tag(YAMLFormatter.Mode.prettify)
                Text("Validate").tag(YAMLFormatter.Mode.validate)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 240)
        }
        .onAppear {
            guard !restored else { return }
            restored = true
            if let value = model.loadOptionsObject(for: "yaml-formatter")["mode"] as? String,
               let parsed = YAMLFormatter.Mode(rawValue: value) { mode = parsed }
        }
        .onChange(of: mode) { _, _ in
            model.saveOptionsObject(["mode": mode.rawValue], for: "yaml-formatter")
        }
    }
}
