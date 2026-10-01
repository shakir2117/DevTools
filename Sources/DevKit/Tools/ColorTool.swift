import SwiftUI
import DevKitCore

struct ColorTool: Tool {
    let id = "color"
    let name = "Color"
    let summary = "Convert HEX, RGB, HSL, HSB, and CMYK"
    let symbol = "paintpalette"
    let category = ToolCategory.converters
    func makeView() -> AnyView { AnyView(ColorToolView()) }
}

struct ColorToolView: View {
    @EnvironmentObject private var model: AppModel
    @State private var text = "#336699"
    @State private var picked = Color(red: 0.2, green: 0.4, blue: 0.6)
    @State private var output = ""
    @State private var issue: ToolIssue?
    @State private var restored = false
    @State private var updating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ColorPicker("Pick", selection: $picked, supportsOpacity: true)
                    .frame(maxWidth: 180)
                TextField("Color", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                Button("Sample") {
                    text = "#FF8800CC"
                    applyText()
                }
                Spacer()
            }
            Text(output.isEmpty ? " " : output)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .textSelection(.enabled)
                .padding(10)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            if let issue {
                Text(issue.display).foregroundStyle(.red)
            }
        }
        .padding(12)
        .onAppear {
            guard !restored else { return }
            restored = true
            text = model.loadOptionsObject(for: "color")["text"] as? String ?? "#336699"
            applyText()
        }
        .onChange(of: text) { _, _ in
            guard !updating else { return }
            applyText()
            model.saveOptionsObject(["text": text], for: "color")
        }
        .onChange(of: picked) { _, newValue in
            guard !updating else { return }
            let resolved = NSColor(newValue).usingColorSpace(.sRGB) ?? NSColor(newValue)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
            let color = RGBA(r: Double(r), g: Double(g), b: Double(b), a: Double(a))
            updating = true
            text = ColorConvert.hex(color)
            output = ColorConvert.describe(color)
            issue = nil
            updating = false
            model.saveOptionsObject(["text": text], for: "color")
        }
    }

    private func applyText() {
        switch ColorConvert.parse(text) {
        case let .success(color):
            output = ColorConvert.describe(color)
            issue = nil
            updating = true
            picked = Color(red: color.r, green: color.g, blue: color.b, opacity: color.a)
            updating = false
        case let .failure(problem):
            issue = problem
        }
    }
}
