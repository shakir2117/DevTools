import SwiftUI
import DevKitCore

struct NumberBaseTool: Tool {
    let id = "number-base"
    let name = "Number Base"
    let summary = "Convert integers between bases 2 and 36"
    let symbol = "number.circle"
    let category = ToolCategory.converters
    func makeView() -> AnyView { AnyView(NumberBaseToolView()) }
}

struct NumberBaseToolView: View {
    @EnvironmentObject private var model: AppModel
    @State private var fromBase = 10
    @State private var toBase = 16
    @State private var uppercase = false
    @State private var restored = false

    var body: some View {
        let fromBase = fromBase
        let toBase = toBase
        let uppercase = uppercase
        TextToolView(
            toolID: "number-base",
            sample: "255",
            runToken: "\(fromBase)|\(toBase)|\(uppercase)",
            transform: { NumberBase.convert($0, from: fromBase, to: toBase, uppercase: uppercase) }
        ) {
            HStack(spacing: 12) {
                Stepper("From: \(fromBase)", value: $fromBase, in: 2...36)
                Stepper("To: \(toBase)", value: $toBase, in: 2...36)
                Button("Swap") {
                    let current = self.fromBase
                    self.fromBase = self.toBase
                    self.toBase = current
                }
                Toggle("Uppercase", isOn: $uppercase)
                Spacer()
            }
        }
        .onAppear(perform: restore)
        .onChange(of: fromBase) { _, _ in persist() }
        .onChange(of: toBase) { _, _ in persist() }
        .onChange(of: uppercase) { _, _ in persist() }
    }

    private func restore() {
        guard !restored else { return }
        restored = true
        let object = model.loadOptionsObject(for: "number-base")
        if let value = object["from"] as? Int, (2...36).contains(value) { fromBase = value }
        if let value = object["to"] as? Int, (2...36).contains(value) { toBase = value }
        uppercase = object["uppercase"] as? Bool ?? false
    }

    private func persist() {
        model.saveOptionsObject(["from": fromBase, "to": toBase, "uppercase": uppercase], for: "number-base")
    }
}
