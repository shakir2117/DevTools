import SwiftUI
import DevKitCore

struct DotEnvTool: Tool {
    let id = "dotenv"
    let name = ".env Editor"
    let summary = "KEY=value, quotes, and comments to JSON, dotenv, or shell export"
    let symbol = "doc.badge.gearshape"
    let category = ToolCategory.converters
    func makeView() -> AnyView { AnyView(DotEnvToolView()) }
}

struct DotEnvToolView: View {
    @EnvironmentObject private var model: AppModel
    @State private var format: DotEnv.Format = .json
    @State private var restored = false

    var body: some View {
        let chosen = format
        TextToolView(
            toolID: "dotenv",
            sample: "# comment\nexport FOO=\"a b\"\nBAR=c\n",
            runToken: chosen.rawValue,
            canSwap: false,
            transform: { DotEnv.convert($0, format: chosen) }
        ) {
            Picker("Output", selection: $format) {
                Text("JSON").tag(DotEnv.Format.json)
                Text("dotenv").tag(DotEnv.Format.dotenv)
                Text("shell export").tag(DotEnv.Format.shell)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320, alignment: .leading)
        }
        .onAppear(perform: restore)
        .onChange(of: format) { _, _ in
            model.saveOptionsObject(["format": format.rawValue], for: "dotenv")
        }
    }

    private func restore() {
        guard !restored else { return }
        restored = true
        if let raw = model.loadOptionsObject(for: "dotenv")["format"] as? String, let parsed = DotEnv.Format(rawValue: raw) {
            format = parsed
        }
    }
}
