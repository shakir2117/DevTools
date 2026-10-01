import SwiftUI
import DevKitCore

struct HTTPStatusTool: Tool {
    let id = "http-status"
    let name = "HTTP Status"
    let summary = "Search the HTTP status code reference"
    let symbol = "list.number"
    let category = ToolCategory.networking
    func makeView() -> AnyView { AnyView(HTTPStatusToolView()) }
}

struct HTTPStatusToolView: View {
    @State private var query = ""

    private var entries: [HTTPStatus.Entry] { HTTPStatus.search(query) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Search codes", text: $query)
                .textFieldStyle(.roundedBorder)
            List(entries) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(entry.code) \(entry.reason)").font(.headline)
                    Text(entry.summary).foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
    }
}
