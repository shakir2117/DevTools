import SwiftUI
import DevKitCore

struct HTMLEntityTool: Tool {
    let id = "html-entity"
    let name = "HTML Entity"
    let summary = "Encode and decode named and numeric HTML entities"
    let symbol = "lessthan"
    let category = ToolCategory.encoders
    func makeView() -> AnyView { AnyView(HTMLEntityToolView()) }
}

struct HTMLEntityToolView: View {
    @EnvironmentObject private var model: AppModel
    @State private var direction: HTMLEntities.Direction = .encode
    @State private var style: HTMLEntities.Style = .named
    @State private var restored = false

    var body: some View {
        let chosenDirection = direction
        let chosenStyle = style
        TextToolView(
            toolID: "html-entity",
            sample: "Tom & Jerry <3 \"quotes\" é",
            runToken: "\(chosenDirection.rawValue)|\(chosenStyle.rawValue)",
            transform: { HTMLEntities.convert($0, direction: chosenDirection, style: chosenStyle) }
        ) {
            HStack(spacing: 12) {
                Picker("Direction", selection: $direction) {
                    Text("Encode").tag(HTMLEntities.Direction.encode)
                    Text("Decode").tag(HTMLEntities.Direction.decode)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
                Picker("Style", selection: $style) {
                    Text("Named").tag(HTMLEntities.Style.named)
                    Text("Decimal").tag(HTMLEntities.Style.decimal)
                    Text("Hex").tag(HTMLEntities.Style.hexadecimal)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 280)
                .disabled(direction == .decode)
                Spacer()
            }
        }
        .onAppear(perform: restore)
        .onChange(of: direction) { _, _ in persist() }
        .onChange(of: style) { _, _ in persist() }
    }

    private func restore() {
        guard !restored else { return }
        restored = true
        let object = model.loadOptionsObject(for: "html-entity")
        if let value = object["direction"] as? String, let parsed = HTMLEntities.Direction(rawValue: value) { direction = parsed }
        if let value = object["style"] as? String, let parsed = HTMLEntities.Style(rawValue: value) { style = parsed }
    }

    private func persist() {
        model.saveOptionsObject(["direction": direction.rawValue, "style": style.rawValue], for: "html-entity")
    }
}
