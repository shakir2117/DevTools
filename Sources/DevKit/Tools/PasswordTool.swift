import SwiftUI
import DevKitCore

struct PasswordTool: Tool {
    let id = "password"
    let name = "Password"
    let summary = "Random passwords and passphrases with an entropy meter"
    let symbol = "lock.fill"
    let category = ToolCategory.generators
    func makeView() -> AnyView { AnyView(PasswordToolView()) }
}

struct PasswordToolView: View {
    @EnvironmentObject private var model: AppModel
    @State private var passphrase = false
    @State private var length = 20
    @State private var wordCount = 6
    @State private var lowercase = true
    @State private var uppercase = true
    @State private var digits = true
    @State private var symbols = true
    @State private var ambiguous = true
    @State private var separator = "-"
    @State private var capitalize = false
    @State private var nonce = 0
    @State private var restored = false

    private var bits: Double {
        PasswordGenerator.entropy(
            passphrase: passphrase,
            length: length,
            wordCount: wordCount,
            lowercase: lowercase,
            uppercase: uppercase,
            digits: digits,
            symbols: symbols,
            excludeAmbiguous: ambiguous
        )
    }

    var body: some View {
        let snapshot = snapshot
        TextToolView(
            toolID: "password",
            sample: "",
            runToken: snapshot.token,
            canSwap: false,
            transform: { _ in snapshot.generate() }
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Picker("Mode", selection: $passphrase) {
                        Text("Password").tag(false)
                        Text("Passphrase").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 220)
                    if passphrase {
                        Stepper("Words: \(wordCount)", value: $wordCount, in: 3...16)
                        TextField("Separator", text: $separator)
                            .frame(width: 70)
                        Toggle("Capitalize", isOn: $capitalize)
                    } else {
                        Stepper("Length: \(length)", value: $length, in: 4...256)
                        Toggle("a-z", isOn: $lowercase)
                        Toggle("A-Z", isOn: $uppercase)
                        Toggle("0-9", isOn: $digits)
                        Toggle("Symbols", isOn: $symbols)
                        Toggle("Avoid ambiguous", isOn: $ambiguous)
                    }
                    Button("Generate") { nonce += 1 }
                    Spacer()
                }
                HStack(spacing: 8) {
                    ProgressView(value: min(bits / 100, 1))
                        .frame(maxWidth: 180)
                    Text(String(format: "%.1f bits", bits))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear(perform: restore)
        .onSample { nonce += 1 }
        .onChange(of: passphrase) { _, _ in persist() }
        .onChange(of: length) { _, _ in persist() }
        .onChange(of: wordCount) { _, _ in persist() }
        .onChange(of: lowercase) { _, _ in persist() }
        .onChange(of: uppercase) { _, _ in persist() }
        .onChange(of: digits) { _, _ in persist() }
        .onChange(of: symbols) { _, _ in persist() }
        .onChange(of: ambiguous) { _, _ in persist() }
        .onChange(of: separator) { _, _ in persist() }
        .onChange(of: capitalize) { _, _ in persist() }
    }

    private var snapshot: PasswordSnapshot {
        PasswordSnapshot(
            passphrase: passphrase,
            length: length,
            wordCount: wordCount,
            lowercase: lowercase,
            uppercase: uppercase,
            digits: digits,
            symbols: symbols,
            ambiguous: ambiguous,
            separator: separator,
            capitalize: capitalize,
            nonce: nonce
        )
    }

    private func restore() {
        guard !restored else { return }
        restored = true
        let object = model.loadOptionsObject(for: "password")
        passphrase = object["passphrase"] as? Bool ?? false
        if let value = object["length"] as? Int { length = value }
        if let value = object["wordCount"] as? Int { wordCount = value }
        lowercase = object["lowercase"] as? Bool ?? true
        uppercase = object["uppercase"] as? Bool ?? true
        digits = object["digits"] as? Bool ?? true
        symbols = object["symbols"] as? Bool ?? true
        ambiguous = object["ambiguous"] as? Bool ?? true
        separator = object["separator"] as? String ?? "-"
        capitalize = object["capitalize"] as? Bool ?? false
    }

    private func persist() {
        model.saveOptionsObject([
            "passphrase": passphrase,
            "length": length,
            "wordCount": wordCount,
            "lowercase": lowercase,
            "uppercase": uppercase,
            "digits": digits,
            "symbols": symbols,
            "ambiguous": ambiguous,
            "separator": separator,
            "capitalize": capitalize,
        ], for: "password")
    }
}

private struct PasswordSnapshot: Sendable {
    var passphrase: Bool
    var length: Int
    var wordCount: Int
    var lowercase: Bool
    var uppercase: Bool
    var digits: Bool
    var symbols: Bool
    var ambiguous: Bool
    var separator: String
    var capitalize: Bool
    var nonce: Int

    var token: String {
        "\(passphrase)|\(length)|\(wordCount)|\(lowercase)|\(uppercase)|\(digits)|\(symbols)|\(ambiguous)|\(separator)|\(capitalize)|\(nonce)"
    }

    func generate() -> ToolResult {
        _ = nonce
        return PasswordGenerator.generate(
            passphrase: passphrase,
            length: length,
            wordCount: wordCount,
            lowercase: lowercase,
            uppercase: uppercase,
            digits: digits,
            symbols: symbols,
            excludeAmbiguous: ambiguous,
            separator: separator,
            capitalize: capitalize
        )
    }
}
