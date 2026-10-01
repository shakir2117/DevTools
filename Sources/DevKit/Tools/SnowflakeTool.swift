import SwiftUI
import DevKitCore

struct SnowflakeTool: Tool {
    let id = "snowflake"
    let name = "Snowflake ID"
    let summary = "Decode Twitter and Discord snowflake ids"
    let symbol = "snowflake"
    let category = ToolCategory.encoders
    func makeView() -> AnyView { AnyView(SnowflakeToolView()) }
}

struct SnowflakeToolView: View {
    @EnvironmentObject private var model: AppModel
    @State private var kind: SnowflakeID.Kind = .twitter
    @State private var restored = false

    var body: some View {
        let chosen = kind
        TextToolView(
            toolID: "snowflake",
            sample: "1304167373735464960",
            runToken: chosen.rawValue,
            canSwap: false,
            transform: { SnowflakeID.decode($0, kind: chosen) }
        ) {
            Picker("Layout", selection: $kind) {
                Text("Twitter").tag(SnowflakeID.Kind.twitter)
                Text("Discord").tag(SnowflakeID.Kind.discord)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 220, alignment: .leading)
        }
        .onAppear {
            guard !restored else { return }
            restored = true
            if let raw = model.loadOptionsObject(for: "snowflake")["kind"] as? String, let parsed = SnowflakeID.Kind(rawValue: raw) {
                kind = parsed
            }
        }
        .onChange(of: kind) { _, _ in
            model.saveOptionsObject(["kind": kind.rawValue], for: "snowflake")
        }
    }
}
