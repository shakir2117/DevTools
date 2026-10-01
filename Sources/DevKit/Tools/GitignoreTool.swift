import SwiftUI
import DevKitCore

struct GitignoreTool: Tool {
    let id = "gitignore"
    let name = ".gitignore Builder"
    let summary = "Swift, Node, Python, and macOS ignore rules"
    let symbol = "eye.slash"
    let category = ToolCategory.generators
    func makeView() -> AnyView { AnyView(GitignoreToolView()) }
}

struct GitignoreToolView: View {
    @EnvironmentObject private var model: AppModel
    @State private var swift = true
    @State private var node = false
    @State private var python = false
    @State private var macOS = true
    @State private var output = ""
    @State private var restored = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FlowRow(spacing: 16, lineSpacing: 8) {
                Toggle("Swift", isOn: $swift)
                Toggle("Node", isOn: $node)
                Toggle("Python", isOn: $python)
                Toggle("macOS", isOn: $macOS)
            }
            CodePane(text: .constant(output), editable: false)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolPage()
        .onAppear {
            guard !restored else { return }
            restored = true
            let saved = model.loadOptionsObject(for: "gitignore")
            swift = saved["swift"] as? Bool ?? swift
            node = saved["node"] as? Bool ?? node
            python = saved["python"] as? Bool ?? python
            macOS = saved["macos"] as? Bool ?? macOS
            refresh()
        }
        .onChange(of: swift) { _, _ in refresh() }
        .onChange(of: node) { _, _ in refresh() }
        .onChange(of: python) { _, _ in refresh() }
        .onChange(of: macOS) { _, _ in refresh() }
        .onSample {
            swift = true
            node = true
            python = true
            macOS = true
        }
    }

    private func refresh() {
        output = GitignoreBuilder.build(swift: swift, node: node, python: python, macOS: macOS)
        model.saveOptionsObject(["swift": swift, "node": node, "python": python, "macos": macOS], for: "gitignore")
    }
}
