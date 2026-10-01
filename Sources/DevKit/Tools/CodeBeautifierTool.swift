import SwiftUI
import DevKitCore

struct CodeBeautifierTool: Tool {
    let id = "code-beautifier"
    let name = "Code Beautifier"
    let summary = "Format JavaScript, CSS, SCSS, and LESS with Prettier"
    let symbol = "paintbrush"
    let category = ToolCategory.formatters
    func makeView() -> AnyView { AnyView(CodeBeautifierToolView()) }
}

struct CodeBeautifierToolView: View {
    @EnvironmentObject private var model: AppModel
    @State private var language: PrettierEngine.Language = .javascript
    @State private var indent = "2"
    @State private var restored = false

    var body: some View {
        let chosen = language
        let width = indent
        TextToolView(
            toolID: "code-beautifier",
            sample: "const answer={value:1+2}",
            runToken: "\(chosen.rawValue)|\(width)",
            canSwap: true,
            transform: { text in
                let tabs = width == "tab"
                let size = Int(width) ?? 2
                return PrettierEngine.format(text, language: chosen, tabWidth: size, useTabs: tabs)
            }
        ) {
            Picker("Language", selection: $language) {
                ForEach(PrettierEngine.Language.allCases, id: \.self) { item in
                    Text(item.title).tag(item)
                }
            }
            .frame(maxWidth: 220)
            Picker("Indent", selection: $indent) {
                Text("2 spaces").tag("2")
                Text("4 spaces").tag("4")
                Text("Tab").tag("tab")
            }
            .frame(maxWidth: 160)
        }
        .onAppear(perform: restore)
        .onChange(of: language) { _, _ in persist() }
        .onChange(of: indent) { _, _ in persist() }
    }

    private func restore() {
        guard !restored else { return }
        restored = true
        let saved = model.loadOptionsObject(for: "code-beautifier")
        if let value = saved["language"] as? String, let parsed = PrettierEngine.Language(rawValue: value) {
            language = parsed
        }
        if let value = saved["indent"] as? String {
            indent = value
        }
    }

    private func persist() {
        model.saveOptionsObject(["language": language.rawValue, "indent": indent], for: "code-beautifier")
    }
}
