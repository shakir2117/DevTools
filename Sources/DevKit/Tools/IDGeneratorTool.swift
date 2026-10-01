import SwiftUI
import DevKitCore

struct IDGeneratorTool: Tool {
    let id = "id-generator"
    let name = "ID Generator"
    let summary = "UUID v4, UUID v7, ULID, and NanoID"
    let symbol = "barcode"
    let category = ToolCategory.generators
    func makeView() -> AnyView { AnyView(IDGeneratorToolView()) }
}

struct IDGeneratorToolView: View {
    @EnvironmentObject private var model: AppModel
    @State private var kind: IDGenerator.Kind = .uuidV4
    @State private var count = 5
    @State private var uppercase = false
    @State private var hyphens = true
    @State private var nanoLength = 21
    @State private var nonce = 0
    @State private var restored = false

    var body: some View {
        let chosenKind = kind
        let chosenCount = count
        let chosenUpper = uppercase
        let chosenHyphens = hyphens
        let chosenLength = nanoLength
        let chosenNonce = nonce
        TextToolView(
            toolID: "id-generator",
            sample: "",
            runToken: "\(chosenKind.rawValue)|\(chosenCount)|\(chosenUpper)|\(chosenHyphens)|\(chosenLength)|\(chosenNonce)",
            canSwap: false,
            transform: { _ in
                _ = chosenNonce
                return IDGenerator.generate(
                    kind: chosenKind,
                    count: chosenCount,
                    uppercase: chosenUpper,
                    hyphens: chosenHyphens,
                    nanoLength: chosenLength
                )
            }
        ) {
            HStack(spacing: 12) {
                Picker("Kind", selection: $kind) {
                    ForEach(IDGenerator.Kind.allCases, id: \.self) { item in
                        Text(item.title).tag(item)
                    }
                }
                .frame(maxWidth: 160)
                Stepper("Count: \(count)", value: $count, in: 1...1000)
                Toggle("Uppercase", isOn: $uppercase)
                    .disabled(kind == .nanoID)
                Toggle("Hyphens", isOn: $hyphens)
                    .disabled(kind != .uuidV4 && kind != .uuidV7)
                if kind == .nanoID {
                    Stepper("Length: \(nanoLength)", value: $nanoLength, in: 1...128)
                }
                Button("Generate") { nonce += 1 }
                Spacer()
            }
        }
        .onAppear(perform: restore)
        .onSample { nonce += 1 }
        .onChange(of: kind) { _, _ in persist() }
        .onChange(of: count) { _, _ in persist() }
        .onChange(of: uppercase) { _, _ in persist() }
        .onChange(of: hyphens) { _, _ in persist() }
        .onChange(of: nanoLength) { _, _ in persist() }
    }

    private func restore() {
        guard !restored else { return }
        restored = true
        let object = model.loadOptionsObject(for: "id-generator")
        if let value = object["kind"] as? String, let parsed = IDGenerator.Kind(rawValue: value) { kind = parsed }
        if let value = object["count"] as? Int { count = min(1000, max(1, value)) }
        uppercase = object["uppercase"] as? Bool ?? false
        hyphens = object["hyphens"] as? Bool ?? true
        if let value = object["nanoLength"] as? Int { nanoLength = min(128, max(1, value)) }
    }

    private func persist() {
        model.saveOptionsObject([
            "kind": kind.rawValue,
            "count": count,
            "uppercase": uppercase,
            "hyphens": hyphens,
            "nanoLength": nanoLength,
        ], for: "id-generator")
    }
}
