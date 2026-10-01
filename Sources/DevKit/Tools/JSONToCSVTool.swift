import SwiftUI
import DevKitCore

struct JSONToCSVTool: Tool {
    let id = "json-csv"
    let name = "JSON → CSV"
    let summary = "Flatten nested JSON into a CSV with dot keys"
    let symbol = "tablecells.badge.ellipsis"
    let category = ToolCategory.converters
    func makeView() -> AnyView { AnyView(JSONToCSVToolView()) }
}

struct JSONToCSVToolView: View {
    @EnvironmentObject private var model: AppModel
    @State private var delimiter = ","
    @State private var restored = false

    var body: some View {
        let separator = delimiter.first ?? ","
        TextToolView(
            toolID: "json-csv",
            sample: #"[{"user":{"name":"Ada","id":1},"tags":["a","b"]}]"#,
            runToken: String(separator),
            canSwap: false,
            transform: { JSONToCSV.convert($0, delimiter: separator) }
        ) {
            HStack {
                Text("Delimiter")
                TextField(",", text: $delimiter)
                    .frame(width: 48)
                Spacer()
            }
        }
        .onAppear {
            guard !restored else { return }
            restored = true
            delimiter = model.loadOptionsObject(for: "json-csv")["delimiter"] as? String ?? ","
        }
        .onChange(of: delimiter) { _, _ in
            model.saveOptionsObject(["delimiter": String(delimiter.prefix(1))], for: "json-csv")
        }
    }
}
