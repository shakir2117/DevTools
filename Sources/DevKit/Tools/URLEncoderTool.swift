import SwiftUI
import DevKitCore

struct URLEncoderTool: Tool {
    let id = "url-encoder"
    let name = "URL Encoder"
    let summary = "Percent-encode or decode a component or a full URL"
    let symbol = "percent"
    let category = ToolCategory.encoders

    func makeView() -> AnyView { AnyView(URLEncoderToolView()) }
}

struct URLEncoderToolView: View {
    @EnvironmentObject private var model: AppModel
    @State private var direction: URLTextEncoder.Direction = .encode
    @State private var scope: URLTextEncoder.Scope = .component
    @State private var restored = false

    var body: some View {
        let chosenDirection = direction
        let chosenScope = scope
        TextToolView(
            toolID: "url-encoder",
            sample: "a b/c?x=1&y=hello world",
            runToken: "\(chosenDirection.rawValue)|\(chosenScope.rawValue)",
            transform: { text in
                URLTextEncoder.convert(text, direction: chosenDirection, scope: chosenScope)
            }
        ) {
            HStack(spacing: 12) {
                Picker("Direction", selection: $direction) {
                    Text("Encode").tag(URLTextEncoder.Direction.encode)
                    Text("Decode").tag(URLTextEncoder.Direction.decode)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
                Picker("Scope", selection: $scope) {
                    Text("Component").tag(URLTextEncoder.Scope.component)
                    Text("Full URL").tag(URLTextEncoder.Scope.fullURL)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 240)
                Spacer()
            }
        }
        .onAppear(perform: restore)
        .onChange(of: direction) { _, _ in persist() }
        .onChange(of: scope) { _, _ in persist() }
    }

    private func restore() {
        guard !restored else { return }
        restored = true
        guard let raw = model.blob(for: "url-encoder").options,
              let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        if let value = object["direction"] as? String, let parsed = URLTextEncoder.Direction(rawValue: value) {
            direction = parsed
        }
        if let value = object["scope"] as? String, let parsed = URLTextEncoder.Scope(rawValue: value) {
            scope = parsed
        }
    }

    private func persist() {
        let object: [String: Any] = ["direction": direction.rawValue, "scope": scope.rawValue]
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let json = String(data: data, encoding: .utf8) else { return }
        model.setOptions(json, for: "url-encoder")
    }
}
