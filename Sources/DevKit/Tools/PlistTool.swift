import SwiftUI
import UniformTypeIdentifiers
import DevKitCore

struct PlistTool: Tool {
    let id = "plist"
    let name = "Plist Editor"
    let summary = "XML or binary property lists to JSON, and JSON back to XML"
    let symbol = "list.bullet.rectangle"
    let category = ToolCategory.converters
    func makeView() -> AnyView { AnyView(PlistToolView()) }
}

struct PlistToolView: View {
    @EnvironmentObject private var model: AppModel
    @State private var direction: PlistEdit.Direction = .toJSON
    @State private var fileNote = ""
    @State private var pushedOutput = ""
    @State private var restored = false

    var body: some View {
        let chosen = direction
        TextToolView(
            toolID: "plist",
            sample: #"{"name":"DevKit"}"#,
            runToken: chosen.rawValue,
            pushedOutput: pushedOutput,
            transform: { PlistEdit.convert($0, direction: chosen) }
        ) {
            FlowRow(spacing: 10, lineSpacing: 8) {
                Picker("Direction", selection: $direction) {
                    Text("To JSON").tag(PlistEdit.Direction.toJSON)
                    Text("To XML").tag(PlistEdit.Direction.toXML)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                Button("Open Plist…") { openFile() }
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
        .onChange(of: direction) { _, _ in persist() }
    }

    private func openFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.propertyList, .xml, .data]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        fileNote = "Reading \(url.lastPathComponent)…"
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Self.load(url)
            DispatchQueue.main.async {
                if let issue = result.issue {
                    fileNote = issue.message
                } else {
                    pushedOutput = result.output
                    fileNote = "Converted \(url.lastPathComponent)."
                }
            }
        }
    }

    private static func load(_ url: URL) -> ToolResult {
        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values.isRegularFile == true else { return .failure("Choose a regular file.") }
            guard let size = values.fileSize, size <= 2_000_000 else { return .failure("File is larger than 2 MB.") }
            return PlistEdit.dataToJSON(try Data(contentsOf: url))
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    private func restore() {
        guard !restored else { return }
        restored = true
        if let raw = model.loadOptionsObject(for: "plist")["direction"] as? String, let parsed = PlistEdit.Direction(rawValue: raw) {
            direction = parsed
        }
    }

    private func persist() {
        model.saveOptionsObject(["direction": direction.rawValue], for: "plist")
    }
}
