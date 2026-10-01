import SwiftUI
import DevKitCore

struct XMLToJSONTool: Tool {
    let id = "xml-json"
    let name = "XML → JSON"
    let summary = "Map elements, attributes, text, and repeated tags"
    let symbol = "arrow.right"
    let category = ToolCategory.converters
    func makeView() -> AnyView { AnyView(XMLToJSONToolView()) }
}

struct XMLToJSONToolView: View {
    var body: some View {
        TextToolView(
            toolID: "xml-json",
            sample: "<book id=\"1\"><title>Hi</title><tag>a</tag><tag>b</tag></book>",
            runToken: "xml-json",
            canSwap: false,
            transform: { XMLToJSON.convert($0) }
        ) {
            Text("Attributes use @, mixed text uses #text, repeated elements become arrays.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
