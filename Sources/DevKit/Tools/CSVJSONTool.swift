import SwiftUI
import DevKitCore

struct CSVJSONTool: Tool {
    let id = "csv-json"
    let name = "CSV ↔ JSON"
    let summary = "Convert CSV and JSON, including quoted fields"
    let symbol = "tablecells"
    let category = ToolCategory.converters
    func makeView() -> AnyView { AnyView(CSVJSONToolView()) }
}

private enum CSVDirection: String { case csvToJSON, jsonToCSV }

struct CSVJSONToolView: View {
    @EnvironmentObject private var model: AppModel
    @State private var direction: CSVDirection = .csvToJSON
    @State private var delimiter = ","
    @State private var header = true
    @State private var infer = true
    @State private var restored = false

    private var separator: Character { delimiter.first ?? "," }

    var body: some View {
        let direction = direction
        let separator = separator
        let header = header
        let infer = infer
        TextToolView(
            toolID: "csv-json",
            sample: "name,note\n\"Doe, Jane\",\"line1\nline2\"\nage,3\n",
            runToken: "\(direction.rawValue)|\(separator)|\(header)|\(infer)",
            transform: { text in
                if direction == .csvToJSON {
                    return CSVJSON.csvToJSON(text, delimiter: separator, header: header, infer: infer)
                }
                return CSVJSON.jsonToCSV(text, delimiter: separator, header: header)
            }
        ) {
            HStack(spacing: 12) {
                Picker("Direction", selection: $direction) {
                    Text("CSV to JSON").tag(CSVDirection.csvToJSON)
                    Text("JSON to CSV").tag(CSVDirection.jsonToCSV)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 280)
                TextField("Delimiter", text: $delimiter)
                    .frame(width: 48)
                Toggle("Header", isOn: $header)
                Toggle("Infer types", isOn: $infer)
                    .disabled(direction != .csvToJSON)
                Spacer()
            }
        }
        .onAppear(perform: restore)
        .onChange(of: direction) { _, _ in persist() }
        .onChange(of: delimiter) { _, _ in persist() }
        .onChange(of: header) { _, _ in persist() }
        .onChange(of: infer) { _, _ in persist() }
    }

    private func restore() {
        guard !restored else { return }
        restored = true
        let object = model.loadOptionsObject(for: "csv-json")
        if let value = object["direction"] as? String, let parsed = CSVDirection(rawValue: value) { direction = parsed }
        delimiter = object["delimiter"] as? String ?? ","
        header = object["header"] as? Bool ?? true
        infer = object["infer"] as? Bool ?? true
    }

    private func persist() {
        model.saveOptionsObject([
            "direction": direction.rawValue,
            "delimiter": String(delimiter.prefix(1)),
            "header": header,
            "infer": infer,
        ], for: "csv-json")
    }
}
