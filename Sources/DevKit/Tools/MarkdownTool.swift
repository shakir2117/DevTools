import SwiftUI
import AppKit
import PDFKit
import DevKitCore

struct MarkdownTool: Tool {
    let id = "markdown"
    let name = "Markdown Preview"
    let summary = "GitHub-flavored Markdown with HTML and PDF export"
    let symbol = "text.book.closed"
    let category = ToolCategory.inspection
    func makeView() -> AnyView { AnyView(MarkdownToolView()) }
}

struct MarkdownToolView: View {
    @EnvironmentObject private var model: AppModel
    @State private var source = "# Title\n\n| A | B |\n| - | - |\n| 1 | 2 |\n\n- [x] done\n\n```swift\nlet a = 1\n```\n"
    @State private var html = ""
    @State private var issue: ToolIssue?
    @State private var gate = RunGate()

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button("Export HTML") { save(html.data(using: .utf8), name: "preview.html") }
                Button("Export PDF") { exportPDF() }
                Spacer()
            }
            FittedSplit {
                CodePane(text: $source, errorLine: issue?.line)
                    .frame(minWidth: 160, maxWidth: .infinity, maxHeight: .infinity)
            } right: {
                WebPreview(html: html, javaScript: false, width: 800)
                    .frame(minWidth: 160, maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            if let issue { Text(issue.display).foregroundStyle(.red) }
        }
        .padding(12)
        .onAppear {
            if let saved = model.blob(for: "markdown").input { source = saved }
            render()
        }
        .onSample { source = "# Title\n\n| A | B |\n| - | - |\n| 1 | 2 |\n\n- [x] done\n" }
        .onChange(of: source) { _, newValue in
            model.setInput(newValue, for: "markdown")
            render()
        }
        .copyOutput { html.isEmpty ? source : html }
    }

    private func render() {
        let generation = gate.bump()
        let source = source
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.2) {
            let result = MarkdownRender.html(from: source)
            DispatchQueue.main.async {
                guard generation == gate.current() else { return }
                html = result.output
                issue = result.issue
            }
        }
    }

    private func exportPDF() {
        guard let data = html.data(using: .utf8) else { return }
        let attributed = (try? NSAttributedString(data: data, options: [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue,
        ], documentAttributes: nil)) ?? NSAttributedString(string: source)
        let view = NSTextView(frame: NSRect(x: 0, y: 0, width: 540, height: 2000))
        view.textStorage?.setAttributedString(attributed)
        view.sizeToFit()
        let pdf = view.dataWithPDF(inside: view.bounds)
        save(pdf, name: "preview.pdf")
    }

    private func save(_ data: Data?, name: String) {
        guard let data else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = name
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try data.write(to: url)
            model.flash("Saved")
        } catch {
            issue = ToolIssue(message: error.localizedDescription)
        }
    }
}
