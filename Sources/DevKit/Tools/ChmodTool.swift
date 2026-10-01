import SwiftUI
import DevKitCore

struct ChmodTool: Tool {
    let id = "chmod"
    let name = "chmod Calculator"
    let summary = "755, setuid, setgid, and sticky bits as octal or rwx"
    let symbol = "checkmark.shield"
    let category = ToolCategory.inspection
    func makeView() -> AnyView { AnyView(ChmodToolView()) }
}

struct ChmodToolView: View {
    var body: some View {
        TextToolView(
            toolID: "chmod",
            sample: "755",
            runToken: "chmod",
            canSwap: false,
            transform: { ChmodCalc.explain($0) }
        ) {
            EmptyView()
        }
    }
}
