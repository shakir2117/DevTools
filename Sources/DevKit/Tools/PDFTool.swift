import SwiftUI
import UniformTypeIdentifiers
import DevKitCore

struct PDFTool: Tool {
    let id = "pdf"
    let name = "PDF Generator"
    let summary = "Build PDFs from text, Markdown, HTML, or images, then merge and reorder"
    let symbol = "doc.richtext"
    let category = ToolCategory.generators
    func makeView() -> AnyView { AnyView(PDFToolView()) }
}

struct PDFToolView: View {
    @EnvironmentObject private var model: AppModel
    @State private var source = "Hello from DevKit"
    @State private var mode = "text"
    @State private var page = "letter"
    @State private var margin = 36.0
    @State private var imageData: Data?
    @State private var document: Data?
    @State private var order = ""
    @State private var status = "Nothing generated yet."

    private var size: CGSize {
        page == "a4" ? CGSize(width: 595, height: 842) : CGSize(width: 612, height: 792)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Picker("Source", selection: $mode) {
                    Text("Text").tag("text")
                    Text("Markdown").tag("markdown")
                    Text("HTML").tag("html")
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 280)
                Picker("Page", selection: $page) {
                    Text("Letter").tag("letter")
                    Text("A4").tag("a4")
                }
                .frame(width: 140)
                Stepper("Margin \(Int(margin))", value: $margin, in: 18...96, step: 6)
                Button("Add Image…") { addImage() }
                Spacer()
            }
            CodePane(text: $source)
                .frame(minHeight: 180)
            HStack {
                Button("Generate") { generate() }
                Button("Merge PDFs…") { merge() }
                TextField("Reorder, e.g. 2,0,1", text: $order)
                    .frame(maxWidth: 180)
                Button("Reorder") { reorder() }
                Button("Save…") { save() }
                    .disabled(document == nil)
            }
            Text(status).foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            if let saved = model.blob(for: "pdf").input { source = saved }
        }
        .onSample { source = "Hello from DevKit\n\nThis page is the sample." }
        .onChange(of: source) { _, newValue in
            model.setInput(newValue, for: "pdf")
        }
        .copyOutput { source }
    }

    private func generate() {
        let spec = PDFBuilder.PageSpec(
            text: source,
            markdown: mode == "markdown",
            html: mode == "html",
            imageData: imageData
        )
        if let data = PDFBuilder.make(pages: [spec], pageSize: size, margin: margin) {
            document = data
            status = "Generated \(PDFBuilder.pageCount(data)) page(s)."
            imageData = nil
        } else {
            status = "Nothing to put on a page."
        }
    }

    private func addImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        imageData = try? Data(contentsOf: url)
        status = imageData == nil ? "Could not read the image." : "Image will be used for the next Generate."
    }

    private func merge() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        let files = panel.urls.compactMap { try? Data(contentsOf: $0) }
        if let data = PDFBuilder.merge(files) {
            document = data
            status = "Merged \(PDFBuilder.pageCount(data)) page(s)."
        } else {
            status = "Could not merge those PDFs."
        }
    }

    private func reorder() {
        guard let document else { status = "Generate or merge a PDF first."; return }
        let indexes = order.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        if let data = PDFBuilder.reorder(document, order: indexes) {
            self.document = data
            status = "Reordered to \(PDFBuilder.pageCount(data)) page(s)."
        } else {
            status = "Those page indexes did not produce a PDF."
        }
    }

    private func save() {
        guard let document else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "DevKit.pdf"
        panel.allowedContentTypes = [.pdf]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try document.write(to: url)
            status = "Saved \(url.lastPathComponent)."
            model.flash("Saved")
        } catch {
            status = error.localizedDescription
        }
    }
}
