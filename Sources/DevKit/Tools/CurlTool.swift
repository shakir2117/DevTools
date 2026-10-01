import SwiftUI
import DevKitCore

struct CurlTool: Tool {
    let id = "curl"
    let name = "cURL → Code"
    let summary = "Turn a curl command into Swift, Python, JavaScript, Go, or Node"
    let symbol = "terminal"
    let category = ToolCategory.networking
    func makeView() -> AnyView { AnyView(CurlToolView()) }
}

struct CurlToolView: View {
    @State private var language = "swift"

    var body: some View {
        let chosen = language
        TextToolView(
            toolID: "curl",
            sample: "curl -X POST https://example.com/api -H 'Content-Type: application/json' -d '{\"a\":1}'",
            runToken: chosen,
            canSwap: false,
            transform: { CurlTranslate.render($0, language: chosen) }
        ) {
            Picker("Language", selection: $language) {
                Text("Swift").tag("swift")
                Text("Python").tag("python")
                Text("JavaScript").tag("javascript")
                Text("Go").tag("go")
                Text("Node").tag("node")
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 420)
        }
    }
}
