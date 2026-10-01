import SwiftUI

struct HTMLPreviewTool: Tool {
    let id = "html-preview"
    let name = "HTML Preview"
    let summary = "Preview HTML in a web view, with JavaScript and width presets"
    let symbol = "safari"
    let category = ToolCategory.inspection
    func makeView() -> AnyView { AnyView(HTMLPreviewToolView()) }
}

struct HTMLPreviewToolView: View {
    @State private var html = "<!DOCTYPE html><html><body><h1>Hello</h1><p id=\"out\"></p><script>document.getElementById('out').textContent = 'JS on'</script></body></html>"
    @State private var javaScript = true
    @State private var width: CGFloat = 800

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Toggle("JavaScript", isOn: $javaScript)
                Picker("Width", selection: $width) {
                    Text("Mobile").tag(CGFloat(390))
                    Text("Tablet").tag(CGFloat(768))
                    Text("Desktop").tag(CGFloat(1100))
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 280)
                Spacer()
            }
            HStack {
                TextEditor(text: $html)
                    .font(.system(.body, design: .monospaced))
                WebPreview(html: html, javaScript: javaScript, width: width)
                    .frame(width: width)
            }
        }
        .padding(12)
    }
}
