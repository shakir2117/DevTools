import SwiftUI
import DevKitCore

struct CSVViewerTool: Tool {
    let id = "csv-viewer"
    let name = "CSV Viewer"
    let summary = "Sort, search, and detect the delimiter of a CSV"
    let symbol = "tablecells"
    let category = ToolCategory.inspection
    func makeView() -> AnyView { AnyView(CSVViewerToolView()) }
}

struct CSVViewerToolView: View {
    @State private var text = "name,city,score\nAda,London,10\nBea,Paris,7\nCy,London,12\n"
    @State private var delimiter = ","
    @State private var detected = false
    @State private var query = ""
    @State private var sortColumn = 0
    @State private var ascending = true
    @State private var rows: [[String]] = []
    @State private var gate = RunGate()

    private var separator: Character { delimiter.first ?? "," }

    private var filtered: [[String]] {
        guard let header = rows.first else { return [] }
        let body = rows.dropFirst().filter { row in
            query.isEmpty || row.contains { $0.localizedCaseInsensitiveContains(query) }
        }
        let sorted = body.sorted { lhs, rhs in
            let left = sortColumn < lhs.count ? lhs[sortColumn] : ""
            let right = sortColumn < rhs.count ? rhs[sortColumn] : ""
            if let a = Double(left), let b = Double(right) { return ascending ? a < b : a > b }
            return ascending ? left.localizedStandardCompare(right) == .orderedAscending : left.localizedStandardCompare(right) == .orderedDescending
        }
        return [header] + sorted
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                TextField("Delimiter", text: $delimiter)
                    .frame(width: 48)
                Toggle("Detect", isOn: $detected)
                TextField("Filter", text: $query)
                Text("\(max(filtered.count - 1, 0)) rows")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 90)
            if let header = filtered.first {
                ScrollView([.horizontal, .vertical]) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 0) {
                            ForEach(Array(header.enumerated()), id: \.offset) { index, name in
                                Button(name.isEmpty ? "Column \(index + 1)" : name) {
                                    if sortColumn == index { ascending.toggle() } else { sortColumn = index; ascending = true }
                                }
                                .frame(width: 160, alignment: .leading)
                            }
                        }
                        .font(.caption.weight(.semibold))
                        ForEach(Array(filtered.dropFirst().prefix(5000).enumerated()), id: \.offset) { _, row in
                            HStack(spacing: 0) {
                                ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                                    Text(cell)
                                        .lineLimit(1)
                                        .frame(width: 160, alignment: .leading)
                                }
                            }
                            .font(.system(.body, design: .monospaced))
                        }
                    }
                }
            }
        }
        .padding(12)
        .onAppear { schedule() }
        .onChange(of: text) { _, _ in schedule() }
        .onChange(of: delimiter) { _, _ in schedule() }
        .onChange(of: detected) { _, _ in schedule() }
    }

    private func schedule() {
        let generation = gate.bump()
        let text = text
        let detected = detected
        let separator = separator
        DispatchQueue.global(qos: .userInitiated).async {
            let chosen = detected ? Self.detect(text) : separator
            let parsed = CSVJSON.parse(text, delimiter: chosen)
            DispatchQueue.main.async {
                guard generation == gate.current() else { return }
                if detected { delimiter = String(chosen) }
                rows = parsed
            }
        }
    }

    private static func detect(_ text: String) -> Character {
        let sample = text.split(whereSeparator: \.isNewline).prefix(20).joined(separator: "\n")
        let candidates: [Character] = [",", "\t", ";", "|"]
        let best = candidates.max { lhs, rhs in
            CSVJSON.parse(String(sample), delimiter: lhs).first?.count ?? 0
                < (CSVJSON.parse(String(sample), delimiter: rhs).first?.count ?? 0)
        }
        return best ?? ","
    }
}
