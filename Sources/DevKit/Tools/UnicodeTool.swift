import SwiftUI
import DevKitCore

struct UnicodeTool: Tool {
    let id = "unicode"
    let name = "Unicode Inspector"
    let summary = "Code points, names, categories, and UTF-8 bytes"
    let symbol = "textformat"
    let category = ToolCategory.inspection
    func makeView() -> AnyView { AnyView(UnicodeToolView()) }
}

struct UnicodeToolView: View {
    var body: some View {
        TextToolView(
            toolID: "unicode",
            sample: "A é €",
            runToken: "unicode",
            canSwap: false,
            transform: { UnicodeInspect.describe($0) }
        ) {
            EmptyView()
        }
    }
}
