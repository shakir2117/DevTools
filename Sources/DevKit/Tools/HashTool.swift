import SwiftUI
import UniformTypeIdentifiers
import DevKitCore

struct HashTool: Tool {
    let id = "hash"
    let name = "Hash"
    let summary = "MD5, SHA, HMAC, and bcrypt for text or a file"
    let symbol = "fingerprint"
    let category = ToolCategory.generators
    func makeView() -> AnyView { AnyView(HashToolView()) }
}

struct HashToolView: View {
    @EnvironmentObject private var model: AppModel
    @State private var choice = "sha256"
    @State private var hmac = false
    @State private var key = ""
    @State private var cost = 10
    @State private var verifyHash = ""
    @State private var fileNote = ""
    @State private var pushed = ""
    @State private var restored = false

    private let choices = ["md5", "sha1", "sha256", "sha384", "sha512", "bcrypt"]

    var body: some View {
        let chosen = choice
        let chosenHMAC = hmac
        let chosenKey = key
        let chosenCost = cost
        let chosenVerify = verifyHash
        TextToolView(
            toolID: "hash",
            sample: "abc",
            runToken: "\(chosen)|\(chosenHMAC)|\(chosenKey)|\(chosenCost)|\(chosenVerify)",
            canSwap: false,
            pushedOutput: pushed,
            transform: { text in
                if chosen == "bcrypt" {
                    if !chosenVerify.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        return Bcrypt.verify(password: text, hash: chosenVerify)
                    }
                    return Bcrypt.hash(password: text, cost: chosenCost)
                }
                let algorithm = Hashing.Algorithm(rawValue: chosen) ?? .sha256
                return Hashing.hash(text: text, algorithm: algorithm, hmacKey: chosenHMAC ? chosenKey : nil)
            }
        ) {
            HStack(spacing: 12) {
                Picker("Algorithm", selection: $choice) {
                    ForEach(choices, id: \.self) { item in
                        Text(item == "bcrypt" ? "bcrypt" : (Hashing.Algorithm(rawValue: item)?.title ?? item)).tag(item)
                    }
                }
                .frame(maxWidth: 160)
                if choice == "bcrypt" {
                    Stepper("Cost \(cost)", value: $cost, in: 4...14)
                    TextField("Hash to verify", text: $verifyHash)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 280)
                } else {
                    Toggle("HMAC", isOn: $hmac)
                    SecureField("Key", text: $key)
                        .frame(maxWidth: 220)
                        .disabled(!hmac)
                }
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
        .onChange(of: choice) { _, _ in persist() }
        .onChange(of: hmac) { _, _ in persist() }
        .onChange(of: key) { _, _ in persist() }
        .onChange(of: cost) { _, _ in persist() }
        .onChange(of: verifyHash) { _, _ in persist() }
    }

    private func hashFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.data]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if choice == "bcrypt" {
            fileNote = "bcrypt hashes a password, not a file."
            return
        }
        let algorithm = Hashing.Algorithm(rawValue: choice) ?? .sha256
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
        if let value = object["algorithm"] as? String, choices.contains(value) { choice = value }
        hmac = object["hmac"] as? Bool ?? false
        key = object["key"] as? String ?? ""
        if let value = object["cost"] as? Int { cost = min(14, max(4, value)) }
        verifyHash = object["verify"] as? String ?? ""
    }

    private func persist() {
        model.saveOptionsObject([
            "algorithm": choice,
            "hmac": hmac,
            "key": key,
            "cost": cost,
            "verify": verifyHash,
        ], for: "hash")
    }
}
