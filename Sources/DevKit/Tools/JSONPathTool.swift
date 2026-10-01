import SwiftUI
import DevKitCore

struct JSONPathTool: Tool {
    let id = "json-path"
    let name = "JSON Path"
    let summary = "Dot paths, indexes, wildcards, and simple filters"
    let symbol = "point.topleft.down.to.point.bottomright.curvepath"
    let category = ToolCategory.inspection
    func makeView() -> AnyView { AnyView(JSONPathToolView()) }
}

struct JSONPathToolView: View {
    @EnvironmentObject private var model: AppModel
    @State private var path = "$.items[*].id"
    @State private var restored = false

    var body: some View {
        let chosen = path
        TextToolView(
            toolID: "json-path",
            sample: #"{"user":{"name":"Ada"},"items":[{"id":1,"ok":true},{"id":2,"ok":false}]}"#,
            runToken: chosen,
            canSwap: false,
            transform: { JSONPath.query(chosen, json: $0) }
        ) {
            HStack {
                TextField("$.items[?(@.ok == true)].id", text: $path)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                Spacer()
            }
        }
        .onAppear {
            guard !restored else { return }
            restored = true
            path = model.loadOptionsObject(for: "json-path")["path"] as? String ?? path
        }
        .onChange(of: path) { _, _ in
            model.saveOptionsObject(["path": path], for: "json-path")
        }
    }
}
