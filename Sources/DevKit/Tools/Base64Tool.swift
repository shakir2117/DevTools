import SwiftUI
import UniformTypeIdentifiers
import DevKitCore

struct Base64Tool: Tool {
    let id = "base64"
    let name = "Base64"
    let summary = "Encode and decode text or files, standard or URL-safe"
    let symbol = "number"
    let category = ToolCategory.encoders

    func makeView() -> AnyView { AnyView(Base64ToolView()) }
}

struct Base64ToolView: View {
    @EnvironmentObject private var model: AppModel
    @State private var direction: Base64Codec.Direction = .encode
    @State private var alphabet: Base64Codec.Alphabet = .standard
    @State private var restored = false
    @State private var fileNote = ""
    @State private var pushedOutput = ""
    @State private var latestSource = ""

    var body: some View {
        let chosenDirection = direction
        let chosenAlphabet = alphabet
        TextToolView(
            toolID: "base64",
            sample: "Hello, DevKit",
            runToken: "\(chosenDirection.rawValue)|\(chosenAlphabet.rawValue)",
            pushedOutput: pushedOutput,
            onSource: { latestSource = $0 },
            transform: { text in
                Base64Codec.convert(text, direction: chosenDirection, alphabet: chosenAlphabet)
            }
        ) {
            HStack(spacing: 12) {
                Picker("Direction", selection: $direction) {
                    Text("Encode").tag(Base64Codec.Direction.encode)
                    Text("Decode").tag(Base64Codec.Direction.decode)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
                Picker("Alphabet", selection: $alphabet) {
                    Text("Standard").tag(Base64Codec.Alphabet.standard)
                    Text("URL-safe").tag(Base64Codec.Alphabet.urlSafe)
                }
                .frame(maxWidth: 180)
                Button("Encode File…") { encodeFile() }
                Button("Decode to File…") { decodeToFile() }
                if !fileNote.isEmpty {
                    Text(fileNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
        }
        .onAppear(perform: restore)
        .onChange(of: direction) { _, _ in persist() }
        .onChange(of: alphabet) { _, _ in persist() }
    }

    private func encodeFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.data]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let alphabet = alphabet
        fileNote = "Reading \(url.lastPathComponent)…"
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let data = try Data(contentsOf: url)
                let result = Base64Codec.encode(data, alphabet: alphabet)
                DispatchQueue.main.async {
                    pushedOutput = result
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(result, forType: .string)
                    fileNote = "Encoded \(url.lastPathComponent) (\(data.count) bytes) into the output pane."
                }
            } catch {
                DispatchQueue.main.async {
                    fileNote = error.localizedDescription
                }
            }
        }
    }

    private func decodeToFile() {
        let source = latestSource.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = Base64Codec.decode(source, alphabet: alphabet) else {
            fileNote = source.isEmpty ? "Enter Base64 in the input pane first." : "Input is not valid Base64."
            return
        }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "decoded.bin"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try data.write(to: url)
            fileNote = "Wrote \(data.count) bytes to \(url.lastPathComponent)."
        } catch {
            fileNote = error.localizedDescription
        }
    }

    private func restore() {
        guard !restored else { return }
        restored = true
        guard let raw = model.blob(for: "base64").options,
              let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        if let value = object["direction"] as? String, let parsed = Base64Codec.Direction(rawValue: value) {
            direction = parsed
        }
        if let value = object["alphabet"] as? String, let parsed = Base64Codec.Alphabet(rawValue: value) {
            alphabet = parsed
        }
    }

    private func persist() {
        let object: [String: Any] = ["direction": direction.rawValue, "alphabet": alphabet.rawValue]
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let json = String(data: data, encoding: .utf8) else { return }
        model.setOptions(json, for: "base64")
    }
}
