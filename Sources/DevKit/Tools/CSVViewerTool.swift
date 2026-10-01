import SwiftUI
import AppKit
import UniformTypeIdentifiers
import DevKitCore

struct CSVViewerTool: Tool {
    let id = "csv-viewer"
    let name = "CSV Viewer"
    let summary = "Sort, search, and detect the delimiter of a CSV"
    let symbol = "tablecells.fill"
    let category = ToolCategory.inspection
    func makeView() -> AnyView { AnyView(CSVViewerToolView()) }
}

struct CSVViewerToolView: View {
    @EnvironmentObject private var model: AppModel
    @State private var text = "name,city,score\nAda,London,10\nBea,Paris,7\nCy,London,12\n"
    @State private var delimiter = ","
    @State private var detected = false
    @State private var query = ""
    @State private var sortColumn = 0
    @State private var ascending = true
    @State private var rows: [[String]] = []
    @State private var shown: [[String]] = []
    @State private var sourceNote: String?
    @State private var gate = RunGate()
    @State private var tableGate = RunGate()

    private var separator: Character { delimiter.first ?? "," }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                TextField("Delimiter", text: $delimiter)
                    .frame(width: 48)
                Toggle("Detect", isOn: $detected)
                TextField("Filter", text: $query)
                Text("\(max(shown.count - 1, 0)) rows")
                    .foregroundStyle(.secondary)
                Button("Open…") { openFile() }
                Spacer()
            }
            FittedSplit {
                VStack(alignment: .leading, spacing: 8) {
                    if let sourceNote {
                        Text(sourceNote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    } else {
                        CodePane(text: $text)
                    }
                }
                .frame(minWidth: 160, maxWidth: .infinity, maxHeight: .infinity)
            } right: {
                CSVTable(rows: shown, sortColumn: sortColumn, ascending: ascending) { index in
                    if sortColumn == index { ascending.toggle() } else { sortColumn = index; ascending = true }
                }
                .frame(minWidth: 160, maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(12)
        .onAppear {
            if let saved = model.blob(for: "csv-viewer").input { text = saved }
            schedule()
        }
        .onSample {
            sourceNote = nil
            text = "name,city,score\nAda,London,10\nBea,Paris,7\nCy,London,12\n"
        }
        .onChange(of: text) { _, newValue in
            if newValue.utf8.count <= 200_000 {
                sourceNote = nil
                model.setInput(newValue, for: "csv-viewer")
            }
            schedule()
        }
        .onChange(of: delimiter) { _, _ in schedule() }
        .onChange(of: detected) { _, _ in schedule() }
        .onChange(of: query) { _, _ in refreshShown() }
        .onChange(of: sortColumn) { _, _ in refreshShown() }
        .onChange(of: ascending) { _, _ in refreshShown() }
        .copyOutput { text }
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
                refreshShown()
            }
        }
    }

    private func refreshShown() {
        let generation = tableGate.bump()
        let rows = rows
        let query = query
        let sortColumn = sortColumn
        let ascending = ascending
        DispatchQueue.global(qos: .userInitiated).async {
            let next = Self.present(rows, query: query, sortColumn: sortColumn, ascending: ascending)
            DispatchQueue.main.async {
                guard generation == tableGate.current() else { return }
                shown = next
            }
        }
    }

    private func openFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let data = try? Data(contentsOf: url) else { return }
        if data.contains(0) {
            sourceNote = "\(url.lastPathComponent) looks like binary data."
            return
        }
        text = String(decoding: data, as: UTF8.self)
        if data.count > 200_000 {
            sourceNote = "\(url.lastPathComponent) · \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)). The table is the view for this file."
            model.setInput(nil, for: "csv-viewer")
        } else {
            sourceNote = nil
        }
    }

    private static func present(_ rows: [[String]], query: String, sortColumn: Int, ascending: Bool) -> [[String]] {
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

private struct CSVTable: NSViewRepresentable {
    var rows: [[String]]
    var sortColumn: Int
    var ascending: Bool
    var onSort: (Int) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let table = NSTableView()
        table.usesAlternatingRowBackgroundColors = true
        table.columnAutoresizingStyle = .noColumnAutoresizing
        table.style = .fullWidth
        table.delegate = context.coordinator
        table.dataSource = context.coordinator
        table.headerView = NSTableHeaderView()
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.drawsBackground = true
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.rows = rows
        context.coordinator.onSort = onSort
        guard let table = scroll.documentView as? NSTableView else { return }
        context.coordinator.sync(table, sortColumn: sortColumn, ascending: ascending)
    }

    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        var rows: [[String]] = []
        var onSort: (Int) -> Void = { _ in }

        func numberOfRows(in tableView: NSTableView) -> Int {
            max(rows.count - 1, 0)
        }

        func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
            guard let tableColumn, let index = tableView.tableColumns.firstIndex(of: tableColumn) else { return "" }
            let record = rows[row + 1]
            return index < record.count ? record[index] : ""
        }

        func tableView(_ tableView: NSTableView, didClick tableColumn: NSTableColumn) {
            guard let index = tableView.tableColumns.firstIndex(of: tableColumn) else { return }
            onSort(index)
        }

        func sync(_ table: NSTableView, sortColumn: Int, ascending: Bool) {
            let header = rows.first ?? []
            if table.tableColumns.count != header.count {
                for column in table.tableColumns { table.removeTableColumn(column) }
                for (index, name) in header.enumerated() {
                    let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("c\(index)"))
                    column.title = name.isEmpty ? "Column \(index + 1)" : name
                    column.width = 160
                    column.minWidth = 80
                    table.addTableColumn(column)
                }
            } else {
                for (index, name) in header.enumerated() {
                    table.tableColumns[index].title = name.isEmpty ? "Column \(index + 1)" : name
                }
            }
            let image = NSImage(systemSymbolName: ascending ? "chevron.up" : "chevron.down", accessibilityDescription: nil)
            for (index, column) in table.tableColumns.enumerated() {
                table.setIndicatorImage(index == sortColumn ? image : nil, in: column)
            }
            table.reloadData()
        }
    }
}
