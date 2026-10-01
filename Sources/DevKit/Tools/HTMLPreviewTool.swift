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
    @EnvironmentObject private var model: AppModel
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
            FittedSplit {
                CodePane(text: $html)
                    .frame(minWidth: 160, maxWidth: .infinity, maxHeight: .infinity)
            } right: {
                WebPreview(html: html, javaScript: javaScript, width: width)
                    .frame(minWidth: 160, idealWidth: width, maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(12)
        .onAppear {
            if let saved = model.blob(for: "html-preview").input { html = saved }
        }
        .onSample { html = "<!DOCTYPE html><html><body><h1>Hello</h1><p>Sample page</p></body></html>" }
        .onChange(of: html) { _, newValue in
            model.setInput(newValue, for: "html-preview")
        }
        .copyOutput { html }
    }
}
