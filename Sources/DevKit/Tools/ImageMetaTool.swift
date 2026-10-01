import SwiftUI
import UniformTypeIdentifiers
import DevKitCore

struct ImageMetaTool: Tool {
    let id = "exif"
    let name = "Image EXIF"
    let summary = "Dimensions, color, and location, with location removal"
    let symbol = "camera"
    let category = ToolCategory.inspection
    func makeView() -> AnyView { AnyView(ImageMetaToolView()) }
}

struct ImageMetaToolView: View {
    @State private var output = ""
    @State private var note = "Open a local image."
    @State private var image = Data()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FlowRow(spacing: 10, lineSpacing: 8) {
                Button("Open Image…") { openFile() }.fixedSize()
                Button("Save Without Location…") { saveStripped() }
                    .fixedSize()
                    .disabled(image.isEmpty)
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: 320, alignment: .leading)
            }
            CodePane(text: .constant(output), editable: false)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolPage()
        .onSample {
            guard let data = ImageMeta.examplePNG() else { return }
            image = data
            let result = ImageMeta.report(data)
            output = result.issue?.display ?? result.output
            note = "Sample image, 8 by 8."
        }
    }

    private func openFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        note = "Reading \(url.lastPathComponent)…"
        DispatchQueue.global(qos: .userInitiated).async {
            let loaded = Self.load(url).map { data in
                (data, ImageMeta.report(data))
            }
            DispatchQueue.main.async {
                switch loaded {
                case let .failure(issue):
                    note = issue.message
                case let .success(value):
                    image = value.0
                    output = value.1.issue?.display ?? value.1.output
                    note = url.lastPathComponent
                }
            }
        }
    }

    private func saveStripped() {
        let source = image
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "image-without-location.png"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let stripped = ImageMeta.withoutLocation(source)
            let written: Result<(String, String), ToolIssue>
            switch stripped {
            case let .failure(issue):
                written = .failure(issue)
            case let .success(value):
                do {
                    try value.data.write(to: url)
                    written = .success((ImageMeta.report(value.data).output, value.note))
                } catch {
                    written = .failure(ToolIssue(message: error.localizedDescription))
                }
            }
            DispatchQueue.main.async {
                switch written {
                case let .failure(issue):
                    note = issue.message
                case let .success(value):
                    output = value.0
                    note = value.1
                }
            }
        }
    }

    private static func load(_ url: URL) -> Result<Data, ToolIssue> {
        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values.isRegularFile == true else { return .failure(ToolIssue(message: "Choose a regular file.")) }
            guard let size = values.fileSize, size <= 20_000_000 else { return .failure(ToolIssue(message: "Image is larger than 20 MB.")) }
            return .success(try Data(contentsOf: url))
        } catch {
            return .failure(ToolIssue(message: error.localizedDescription))
        }
    }
}
