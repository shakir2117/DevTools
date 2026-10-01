import SwiftUI
import DevKitCore

struct DiffTool: Tool {
    let id = "diff"
    let name = "Text Diff"
    let summary = "Line, word, and character diffs, side by side or unified"
    let symbol = "rectangle.split.2x1"
    let category = ToolCategory.inspection
    func makeView() -> AnyView { AnyView(DiffToolView()) }
}

struct DiffToolView: View {
    @EnvironmentObject private var model: AppModel
    @State private var left = "a\nb\nc"
    @State private var right = "a\nx\nc"
    @State private var granularity: TextDiff.Granularity = .line
    @State private var ignoreWhitespace = false
    @State private var ignoreCase = false
    @State private var sideBySide = true
    @State private var rows: [TextDiff.Row] = []
    @State private var unified = ""
    @State private var restored = false
    @State private var gate = RunGate()

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Picker("Granularity", selection: $granularity) {
                    Text("Line").tag(TextDiff.Granularity.line)
                    Text("Word").tag(TextDiff.Granularity.word)
                    Text("Character").tag(TextDiff.Granularity.character)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 280)
                Toggle("Ignore whitespace", isOn: $ignoreWhitespace)
                Toggle("Ignore case", isOn: $ignoreCase)
                Picker("Layout", selection: $sideBySide) {
                    Text("Side by side").tag(true)
                    Text("Unified").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
            }
            HStack {
                TextEditor(text: $left).font(.system(.body, design: .monospaced))
                TextEditor(text: $right).font(.system(.body, design: .monospaced))
            }
            .frame(minHeight: 140)
            if sideBySide {
                List(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(alignment: .top) {
                        Text(row.left).frame(maxWidth: .infinity, alignment: .leading)
                        Text(row.right).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(color(row.kind))
                }
            } else {
                TextEditor(text: .constant(unified))
                    .font(.system(.body, design: .monospaced))
            }
        }
        .padding(12)
        .onAppear(perform: restore)
        .onChange(of: left) { _, _ in schedule() }
        .onChange(of: right) { _, _ in schedule() }
        .onChange(of: granularity) { _, _ in schedule() }
        .onChange(of: ignoreWhitespace) { _, _ in schedule() }
        .onChange(of: ignoreCase) { _, _ in schedule() }
    }

    private func color(_ kind: String) -> Color {
        switch kind {
        case "delete": return .red
        case "insert": return .green
        case "change": return .orange
        default: return .primary
        }
    }

    private func schedule() {
        let generation = gate.bump()
        let left = left
        let right = right
        let granularity = granularity
        let ignoreWhitespace = ignoreWhitespace
        let ignoreCase = ignoreCase
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.15) {
            let result = TextDiff.diff(left, right, granularity: granularity, ignoreWhitespace: ignoreWhitespace, ignoreCase: ignoreCase)
            DispatchQueue.main.async {
                guard generation == gate.current() else { return }
                rows = result.rows
                unified = result.unified
                guard restored else { return }
                model.saveOptionsObject([
                    "left": String(left.prefix(20_000)),
                    "right": String(right.prefix(20_000)),
                    "granularity": granularity.rawValue,
                    "ignoreWhitespace": ignoreWhitespace,
                    "ignoreCase": ignoreCase,
                ], for: "diff")
            }
        }
    }

    private func restore() {
        guard !restored else { return }
        let object = model.loadOptionsObject(for: "diff")
        left = object["left"] as? String ?? left
        right = object["right"] as? String ?? right
        if let value = object["granularity"] as? String, let parsed = TextDiff.Granularity(rawValue: value) { granularity = parsed }
        ignoreWhitespace = object["ignoreWhitespace"] as? Bool ?? false
        ignoreCase = object["ignoreCase"] as? Bool ?? false
        restored = true
        schedule()
    }
}
