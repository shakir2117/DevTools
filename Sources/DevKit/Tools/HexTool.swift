import SwiftUI
import UniformTypeIdentifiers
import DevKitCore

struct HexTool: Tool {
    let id = "hex"
    let name = "Hex Viewer"
    let summary = "Hex and ASCII dump, with a highlighted range"
    let symbol = "number.square"
    let category = ToolCategory.inspection
    func makeView() -> AnyView { AnyView(HexToolView()) }
}

struct HexToolView: View {
    @EnvironmentObject private var model: AppModel
    @State private var hexInput = false
    @State private var highlightStart = "0"
    @State private var highlightLength = "0"
    @State private var fileNote = ""
    @State private var pushedOutput = ""
    @State private var restored = false

    var body: some View {
        let hex = hexInput
        let start = Int(highlightStart) ?? 0
        let length = Int(highlightLength) ?? 0
        TextToolView(
            toolID: "hex",
            sample: "Hello",
            runToken: "\(hex)|\(start)|\(length)",
            canSwap: false,
            pushedOutput: pushedOutput,
            transform: { HexDump.dump(text: $0, hexInput: hex, highlightStart: start, highlightLength: length) }
        ) {
            FlowRow(spacing: 10, lineSpacing: 8) {
                Picker("Input", selection: $hexInput) {
                    Text("Text").tag(false)
                    Text("Hex").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
                Text("Highlight start")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize()
                TextField("0", text: $highlightStart)
                    .frame(width: 64)
                Text("Length")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize()
                TextField("0", text: $highlightLength)
                    .frame(width: 64)
                Button("Open File…") { openFile(start: start, length: length) }
                    .fixedSize()
                if !fileNote.isEmpty {
                    Text(fileNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: 280, alignment: .leading)
                }
            }
        }
        .onAppear(perform: restore)
        .onSample {
            hexInput = false
            highlightStart = "0"
            highlightLength = "1"
        }
        .onChange(of: hexInput) { _, _ in persist() }
        .onChange(of: highlightStart) { _, _ in persist() }
        .onChange(of: highlightLength) { _, _ in persist() }
    }

    private func openFile(start: Int, length: Int) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.data]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        fileNote = "Reading \(url.lastPathComponent)…"
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Self.load(url, start: start, length: length)
            DispatchQueue.main.async {
                if let issue = result.issue {
                    fileNote = issue.message
                } else {
                    pushedOutput = result.output
                    fileNote = "Loaded \(url.lastPathComponent)."
                }
            }
        }
    }

    private static func load(_ url: URL, start: Int, length: Int) -> ToolResult {
        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values.isRegularFile == true else { return .failure("Choose a regular file.") }
            guard let size = values.fileSize, size <= 2_000_000 else { return .failure("File is larger than 2 MB.") }
            return HexDump.dump(data: try Data(contentsOf: url), highlightStart: start, highlightLength: length)
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    private func restore() {
        guard !restored else { return }
        restored = true
        let object = model.loadOptionsObject(for: "hex")
        hexInput = object["hex"] as? Bool ?? false
        highlightStart = object["start"] as? String ?? "0"
        highlightLength = object["length"] as? String ?? "0"
    }

    private func persist() {
        model.saveOptionsObject(["hex": hexInput, "start": highlightStart, "length": highlightLength], for: "hex")
    }
}
