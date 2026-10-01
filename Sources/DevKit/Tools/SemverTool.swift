import SwiftUI
import DevKitCore

struct SemverTool: Tool {
    let id = "semver"
    let name = "Semantic Version"
    let summary = "Compare, bump, and test ^, ~, and inequality ranges"
    let symbol = "arrow.up.arrow.down"
    let category = ToolCategory.converters
    func makeView() -> AnyView { AnyView(SemverToolView()) }
}

struct SemverToolView: View {
    @EnvironmentObject private var model: AppModel
    @State private var version = "1.2.3"
    @State private var other = "1.2.4"
    @State private var range = "^1.2.0"
    @State private var output = ""
    @State private var restored = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FlowRow(spacing: 10, lineSpacing: 8) {
                TextField("Version", text: $version).frame(width: 160)
                TextField("Compare with", text: $other).frame(width: 160)
                TextField("Range", text: $range).frame(width: 160)
            }
            FlowRow(spacing: 8, lineSpacing: 8) {
                Button("Compare") { show(Semver.compare(version, other)) }
                Button("Range") { show(Semver.satisfies(version, range: range)) }
                Button("Bump major") { show(Semver.bump(version, part: .major)) }
                Button("Bump minor") { show(Semver.bump(version, part: .minor)) }
                Button("Bump patch") { show(Semver.bump(version, part: .patch)) }
            }
            CodePane(text: .constant(output), editable: false)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolPage()
        .onAppear {
            guard !restored else { return }
            restored = true
            let saved = model.loadOptionsObject(for: "semver")
            version = saved["version"] as? String ?? version
            other = saved["other"] as? String ?? other
            range = saved["range"] as? String ?? range
            show(Semver.compare(version, other))
        }
        .onSample {
            version = "1.2.3"
            other = "1.2.4"
            range = "^1.2.0"
            show(Semver.compare("1.2.3", "1.2.4"))
        }
        .onChange(of: version) { _, _ in persist() }
        .onChange(of: other) { _, _ in persist() }
        .onChange(of: range) { _, _ in persist() }
    }

    private func show(_ result: ToolResult) {
        output = result.issue?.display ?? result.output
    }

    private func persist() {
        model.saveOptionsObject(["version": version, "other": other, "range": range], for: "semver")
    }
}
