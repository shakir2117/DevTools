import SwiftUI
import DevKitCore

struct URLParserTool: Tool {
    let id = "url-parser"
    let name = "URL Parser"
    let summary = "Split a URL and edit its query string"
    let symbol = "link"
    let category = ToolCategory.formatters
    func makeView() -> AnyView { AnyView(URLParserToolView()) }
}

struct URLParserToolView: View {
    @State private var raw = "https://ada:secret@example.com:8443/a/b?x=1&y=hello#top"
    @State private var parsed = ParsedURL()
    @State private var issue: ToolIssue?
    @State private var writing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("URL", text: $raw)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                labeled("Scheme", $parsed.scheme)
                labeled("User", $parsed.user)
                labeled("Password", $parsed.password)
                labeled("Host", $parsed.host)
                labeled("Port", $parsed.port)
                labeled("Path", $parsed.path)
                labeled("Fragment", $parsed.fragment)
            }
            Text("Query")
                .font(.caption.weight(.semibold))
            ForEach(Array(parsed.query.enumerated()), id: \.offset) { index, _ in
                HStack {
                    TextField("Name", text: binding(index, isName: true))
                    TextField("Value", text: binding(index, isName: false))
                    Button("Remove") { parsed.query.remove(at: index); rebuild() }
                }
            }
            Button("Add query item") {
                parsed.query.append((name: "", value: ""))
                rebuild()
            }
            if let issue { Text(issue.display).foregroundStyle(.red) }
        }
        .padding(12)
        .onAppear { applyRaw() }
        .onSample { raw = "https://ada:secret@example.com:8443/a/b?x=1&y=hello#top" }
        .onChange(of: raw) { _, _ in
            guard !writing else { return }
            applyRaw()
        }
        .onChange(of: parsed.scheme) { _, _ in rebuild() }
        .onChange(of: parsed.user) { _, _ in rebuild() }
        .onChange(of: parsed.password) { _, _ in rebuild() }
        .onChange(of: parsed.host) { _, _ in rebuild() }
        .onChange(of: parsed.port) { _, _ in rebuild() }
        .onChange(of: parsed.path) { _, _ in rebuild() }
        .onChange(of: parsed.fragment) { _, _ in rebuild() }
    }

    private func labeled(_ title: String, _ text: Binding<String>) -> some View {
        GridRow {
            Text(title).frame(width: 80, alignment: .leading)
            TextField(title, text: text)
        }
    }

    private func binding(_ index: Int, isName: Bool) -> Binding<String> {
        Binding(
            get: {
                guard parsed.query.indices.contains(index) else { return "" }
                return isName ? parsed.query[index].name : parsed.query[index].value
            },
            set: { newValue in
                guard parsed.query.indices.contains(index) else { return }
                if isName { parsed.query[index].name = newValue } else { parsed.query[index].value = newValue }
                rebuild()
            }
        )
    }

    private func applyRaw() {
        switch ParsedURL.parse(raw) {
        case let .success(value):
            parsed = value
            issue = nil
        case let .failure(problem):
            issue = problem
        }
    }

    private func rebuild() {
        guard !writing else { return }
        writing = true
        raw = parsed.render()
        writing = false
    }
}
