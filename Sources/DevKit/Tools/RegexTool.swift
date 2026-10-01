import SwiftUI
import DevKitCore

struct RegexTool: Tool {
    let id = "regex"
    let name = "Regex"
    let summary = "Test NSRegularExpression with matches, groups, and replace"
    let symbol = "text.magnifyingglass"
    let category = ToolCategory.inspection
    func makeView() -> AnyView { AnyView(RegexToolView()) }
}

struct RegexToolView: View {
    @EnvironmentObject private var model: AppModel
    @State private var pattern = #"(\w+)@(\w+)"#
    @State private var text = "a@b and c@d"
    @State private var template = "[$1]"
    @State private var caseInsensitive = false
    @State private var anchors = false
    @State private var dotLines = false
    @State private var outcome = RegexPlayground.Outcome(hits: [], replacement: "", issue: nil)
    @State private var restored = false
    @State private var gate = RunGate()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("Pattern", text: $pattern)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                Picker("Library", selection: Binding(get: { pattern }, set: { pattern = $0 })) {
                    Text("Library").tag(pattern)
                    ForEach(RegexPlayground.library, id: \.pattern) { item in
                        Text(item.name).tag(item.pattern)
                    }
                }
                .frame(width: 140)
            }
            HStack {
                Toggle("Case insensitive", isOn: $caseInsensitive)
                Toggle("^$ match lines", isOn: $anchors)
                Toggle(". matches newline", isOn: $dotLines)
                Spacer()
            }
            HighlightedText(text: text, hits: outcome.hits)
                .frame(minHeight: 120)
            TextField("Subject", text: $text, axis: .vertical)
                .font(.system(.body, design: .monospaced))
                .lineLimit(4...8)
            TextField("Replacement template", text: $template)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
            Text("Matches \(outcome.hits.count)")
                .font(.caption.weight(.semibold))
            List(Array(outcome.hits.enumerated()), id: \.offset) { _, hit in
                VStack(alignment: .leading) {
                    Text(hit.text).font(.system(.body, design: .monospaced))
                    if !hit.groups.isEmpty {
                        Text(hit.groups.enumerated().map { "$\($0.offset + 1)=\($0.element)" }.joined(separator: "  "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Text("Replace preview")
                .font(.caption.weight(.semibold))
            Text(outcome.replacement)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            if let issue = outcome.issue {
                Text(issue.display).foregroundStyle(.red)
            }
        }
        .padding(12)
        .onAppear {
            guard !restored else { return }
            restored = true
            let object = model.loadOptionsObject(for: "regex")
            pattern = object["pattern"] as? String ?? pattern
            text = object["text"] as? String ?? text
            template = object["template"] as? String ?? template
            caseInsensitive = object["caseInsensitive"] as? Bool ?? false
            anchors = object["anchors"] as? Bool ?? false
            dotLines = object["dotLines"] as? Bool ?? false
            evaluate()
        }
        .onChange(of: pattern) { _, _ in schedule() }
        .onChange(of: text) { _, _ in schedule() }
        .onChange(of: template) { _, _ in schedule() }
        .onChange(of: caseInsensitive) { _, _ in schedule() }
        .onChange(of: anchors) { _, _ in schedule() }
        .onChange(of: dotLines) { _, _ in schedule() }
    }

    private func schedule() {
        let generation = gate.bump()
        let pattern = pattern
        let text = text
        let template = template
        let caseInsensitive = caseInsensitive
        let anchors = anchors
        let dotLines = dotLines
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.2) {
            let result = RegexPlayground.run(
                pattern: pattern, text: text, template: template,
                caseInsensitive: caseInsensitive, anchorsMatchLines: anchors, dotMatchesLines: dotLines
            )
            DispatchQueue.main.async {
                guard generation == gate.current() else { return }
                outcome = result
                model.saveOptionsObject([
                    "pattern": pattern, "text": String(text.prefix(20_000)), "template": template,
                    "caseInsensitive": caseInsensitive, "anchors": anchors, "dotLines": dotLines,
                ], for: "regex")
            }
        }
    }

    private func evaluate() { schedule() }
}

private struct HighlightedText: NSViewRepresentable {
    var text: String
    var hits: [RegexPlayground.Hit]

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        let textView = scroll.documentView as? NSTextView
        textView?.isEditable = false
        textView?.isRichText = true
        textView?.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let textView = scroll.documentView as? NSTextView else { return }
        let attributed = NSMutableAttributedString(string: text, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
            .foregroundColor: NSColor.labelColor,
        ])
        for hit in hits where hit.location >= 0 && hit.location + hit.length <= (text as NSString).length {
            attributed.addAttribute(.backgroundColor, value: NSColor.systemYellow.withAlphaComponent(0.45), range: NSRange(location: hit.location, length: hit.length))
        }
        textView.textStorage?.setAttributedString(attributed)
    }
}
