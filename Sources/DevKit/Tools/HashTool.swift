import SwiftUI
import UniformTypeIdentifiers
import DevKitCore

struct HashTool: Tool {
    let id = "hash"
    let name = "Hash"
    let summary = "MD5, SHA, and HMAC for text or a file"
    let symbol = "number.square"
    let category = ToolCategory.generators
    func makeView() -> AnyView { AnyView(HashToolView()) }
}

struct HashToolView: View {
    @EnvironmentObject private var model: AppModel
    @State private var algorithm: Hashing.Algorithm = .sha256
    @State private var hmac = false
    @State private var key = ""
    @State private var fileNote = ""
    @State private var pushed = ""
    @State private var restored = false

    var body: some View {
        let chosenAlgorithm = algorithm
        let chosenHMAC = hmac
        let chosenKey = key
        TextToolView(
            toolID: "hash",
            sample: "abc",
            runToken: "\(chosenAlgorithm.rawValue)|\(chosenHMAC)|\(chosenKey)",
            canSwap: false,
            pushedOutput: pushed,
            transform: { text in
                Hashing.hash(text: text, algorithm: chosenAlgorithm, hmacKey: chosenHMAC ? chosenKey : nil)
            }
        ) {
            HStack(spacing: 12) {
                Picker("Algorithm", selection: $algorithm) {
                    ForEach(Hashing.Algorithm.allCases, id: \.self) { item in
                        Text(item.title).tag(item)
                    }
                }
                .frame(maxWidth: 160)
                Toggle("HMAC", isOn: $hmac)
                SecureField("Key", text: $key)
                    .frame(maxWidth: 220)
                    .disabled(!hmac)
                Button("Hash File…") { hashFile() }
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
        .onChange(of: algorithm) { _, _ in persist() }
        .onChange(of: hmac) { _, _ in persist() }
        .onChange(of: key) { _, _ in persist() }
    }

    private func hashFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.data]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let algorithm = algorithm
        let key = hmac ? key : nil
        fileNote = "Hashing \(url.lastPathComponent)…"
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Hashing.hashFile(at: url, algorithm: algorithm, hmacKey: key)
            DispatchQueue.main.async {
                if let issue = result.issue {
                    fileNote = issue.message
                } else {
                    pushed = result.output
                    fileNote = "Hashed \(url.lastPathComponent)."
                }
            }
        }
    }

    private func restore() {
        guard !restored else { return }
        restored = true
        let object = model.loadOptionsObject(for: "hash")
        if let value = object["algorithm"] as? String, let parsed = Hashing.Algorithm(rawValue: value) { algorithm = parsed }
        hmac = object["hmac"] as? Bool ?? false
        key = object["key"] as? String ?? ""
    }

    private func persist() {
        model.saveOptionsObject([
            "algorithm": algorithm.rawValue,
            "hmac": hmac,
            "key": key,
        ], for: "hash")
    }
}
