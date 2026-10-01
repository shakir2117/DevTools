import SwiftUI
import DevKitCore

struct CodeMinifierTool: Tool {
    let id = "code-minifier"
    let name = "Code Minifier"
    let summary = "Minify JSON, XML, JavaScript, and CSS"
    let symbol = "arrow.down.right.and.arrow.up.left"
    let category = ToolCategory.formatters
    func makeView() -> AnyView { AnyView(CodeMinifierToolView()) }
}

struct CodeMinifierToolView: View {
    @EnvironmentObject private var model: AppModel
    @State private var language: CodeMinify.Language = .javascript
    @State private var restored = false

    var body: some View {
        let chosen = language
        TextToolView(
            toolID: "code-minifier",
            sample: "const value = 1 + 2;\n",
            runToken: chosen.rawValue,
            canSwap: true,
            transform: { CodeMinify.minify($0, language: chosen) }
        ) {
            Picker("Language", selection: $language) {
                ForEach(CodeMinify.Language.allCases, id: \.self) { item in
                    Text(item.title).tag(item)
                }
            }
            .frame(maxWidth: 220)
        }
        .onAppear(perform: restore)
        .onChange(of: language) { _, _ in persist() }
    }

    private func restore() {
        guard !restored else { return }
        restored = true
        if let value = model.loadOptionsObject(for: "code-minifier")["language"] as? String,
           let parsed = CodeMinify.Language(rawValue: value) {
            language = parsed
        }
    }

    private func persist() {
        model.saveOptionsObject(["language": language.rawValue], for: "code-minifier")
    }
}
