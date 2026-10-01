import SwiftUI
import AppKit
import UniformTypeIdentifiers
import DevKitCore

struct QRGeneratorTool: Tool {
    let id = "qr-generator"
    let name = "QR Generator"
    let summary = "QR codes for text, URLs, Wi-Fi, and vCards"
    let symbol = "qrcode"
    let category = ToolCategory.generators
    func makeView() -> AnyView { AnyView(QRGeneratorToolView()) }
}

struct QRReaderTool: Tool {
    let id = "qr-reader"
    let name = "QR Reader"
    let summary = "Read a QR code from a file, a drop, or the clipboard"
    let symbol = "qrcode.viewfinder"
    let category = ToolCategory.inspection
    func makeView() -> AnyView { AnyView(QRReaderToolView()) }
}

struct QRGeneratorToolView: View {
    @State private var kind = "text"
    @State private var text = "https://example.com"
    @State private var ssid = "Lab"
    @State private var password = "secret"
    @State private var security = "WPA"
    @State private var name = "Ada Lovelace"
    @State private var phone = ""
    @State private var email = ""
    @State private var correction = "M"
    @State private var scale = 10
    @State private var foreground = Color.black
    @State private var background = Color.white
    @State private var preview: NSImage?

    private var payload: String {
        QRCode.payload(kind: kind, text: text, ssid: ssid, password: password, security: security, name: name, phone: phone, email: email)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Picker("Kind", selection: $kind) {
                    Text("Text / URL").tag("text")
                    Text("Wi-Fi").tag("wifi")
                    Text("vCard").tag("vcard")
                }
                .pickerStyle(.segmented)
                if kind == "text" {
                    TextField("Text or URL", text: $text, axis: .vertical).lineLimit(3...6)
                } else if kind == "wifi" {
                    TextField("SSID", text: $ssid)
                    SecureField("Password", text: $password)
                    Picker("Security", selection: $security) {
                        Text("WPA").tag("WPA")
                        Text("WEP").tag("WEP")
                        Text("None").tag("nopass")
                    }
                } else {
                    TextField("Name", text: $name)
                    TextField("Phone", text: $phone)
                    TextField("Email", text: $email)
                }
                Picker("Error correction", selection: $correction) {
                    Text("L").tag("L"); Text("M").tag("M"); Text("Q").tag("Q"); Text("H").tag("H")
                }
                .frame(maxWidth: 220)
                Stepper("Scale: \(scale)", value: $scale, in: 4...30)
                ColorPicker("Foreground", selection: $foreground, supportsOpacity: false)
                ColorPicker("Background", selection: $background, supportsOpacity: false)
                HStack {
                    Button("PNG") { save(png, "qr.png") }
                    Button("SVG") { save(svg?.data(using: .utf8), "qr.svg") }
                    Button("PDF") { save(pdf, "qr.pdf") }
                }
            }
            .frame(maxWidth: 360)
            Group {
                if let preview {
                    Image(nsImage: preview).resizable().interpolation(.none).scaledToFit().frame(width: 280, height: 280)
                } else {
                    Text("Enter content to generate a code.").foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(12)
        .onAppear { refresh() }
        .onSample { kind = "text"; text = "https://example.com" }
        .onChange(of: payload) { _, _ in refresh() }
        .onChange(of: correction) { _, _ in refresh() }
        .onChange(of: scale) { _, _ in refresh() }
        .onChange(of: foreground) { _, _ in refresh() }
        .onChange(of: background) { _, _ in refresh() }
    }

    private var colors: ((Double, Double, Double), (Double, Double, Double)) {
        (components(foreground), components(background))
    }

    private var png: Data? {
        let colors = colors
        return QRCode.png(payload: payload, correction: correction, scale: scale, foreground: colors.0, background: colors.1)
    }

    private var pdf: Data? {
        let colors = colors
        return QRCode.pdf(payload: payload, correction: correction, scale: scale, foreground: colors.0, background: colors.1)
    }

    private var svg: String? {
        let colors = colors
        return QRCode.svg(payload: payload, correction: correction, foreground: colors.0, background: colors.1)
    }

    private func refresh() {
        guard let data = png else { preview = nil; return }
        preview = NSImage(data: data)
    }

    private func components(_ color: Color) -> (Double, Double, Double) {
        let resolved = NSColor(color).usingColorSpace(.sRGB) ?? NSColor.black
        return (Double(resolved.redComponent), Double(resolved.greenComponent), Double(resolved.blueComponent))
    }

    private func save(_ data: Data?, _ name: String) {
        guard let data else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = name
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? data.write(to: url)
    }
}

struct QRReaderToolView: View {
    @State private var result = "Drop an image, or choose a file."
    @State private var targeted = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button("Open Image…") { open() }
                Button("Read Clipboard") { readClipboard() }
                Spacer()
            }
            Text(result)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(12)
                .background(targeted ? Color.accentColor.opacity(0.15) : Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .onDrop(of: [.image, .fileURL], isTargeted: $targeted) { providers in
                    load(providers)
                }
        }
        .padding(12)
        .onSample { result = "Open an image of a QR code, or use Read Clipboard." }
    }

    private func open() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        guard panel.runModal() == .OK, let url = panel.url, let data = try? Data(contentsOf: url) else { return }
        show(data)
    }

    private func readClipboard() {
        guard let image = NSImage(pasteboard: .general), let data = pngData(image) else {
            result = "The clipboard has no image."
            return
        }
        show(data)
    }

    private func show(_ data: Data) {
        switch QRCode.read(data: data) {
        case let .success(values): result = values.joined(separator: "\n")
        case let .failure(issue): result = issue.message
        }
    }

    private func pngData(_ image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    private func load(_ providers: [NSItemProvider]) -> Bool {
        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }) {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                guard let data else { return }
                DispatchQueue.main.async { show(data) }
            }
            return true
        }
        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url = item as? URL ?? (item as? Data).flatMap { URL(dataRepresentation: $0, relativeTo: nil) }
                guard let url, let data = try? Data(contentsOf: url) else { return }
                DispatchQueue.main.async { show(data) }
            }
            return true
        }
        return false
    }
}
