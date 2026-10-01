import SwiftUI
import DevKitCore

struct LaunchdTool: Tool {
    let id = "launchd"
    let name = "launchd Plist"
    let summary = "Write a LaunchAgent plist. It is not loaded."
    let symbol = "gearshape.2"
    let category = ToolCategory.generators
    func makeView() -> AnyView { AnyView(LaunchdToolView()) }
}

struct LaunchdToolView: View {
    @EnvironmentObject private var model: AppModel
    @State private var label = "com.example.job"
    @State private var program = "/bin/echo"
    @State private var arguments = "hello"
    @State private var runAtLoad = true
    @State private var interval = "60"
    @State private var standardOut = ""
    @State private var standardError = ""
    @State private var output = ""
    @State private var restored = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], alignment: .leading, spacing: 10) {
                field("Label", $label)
                field("Program", $program)
                field("Interval seconds", $interval)
                field("Standard out", $standardOut)
                field("Standard error", $standardError)
            }
            field("Arguments, one per line", $arguments)
            Toggle("Run at load", isOn: $runAtLoad)
                .fixedSize()
            CodePane(text: .constant(output), editable: false)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolPage()
        .onAppear {
            guard !restored else { return }
            restored = true
            let saved = model.loadOptionsObject(for: "launchd")
            label = saved["label"] as? String ?? label
            program = saved["program"] as? String ?? program
            arguments = saved["arguments"] as? String ?? arguments
            runAtLoad = saved["run"] as? Bool ?? runAtLoad
            interval = saved["interval"] as? String ?? interval
            standardOut = saved["out"] as? String ?? standardOut
            standardError = saved["err"] as? String ?? standardError
            refresh()
        }
        .onSample {
            label = "com.example.job"
            program = "/bin/echo"
            arguments = "hello"
            runAtLoad = true
            interval = "60"
            standardOut = ""
            standardError = ""
        }
        .onChange(of: label) { _, _ in refresh() }
        .onChange(of: program) { _, _ in refresh() }
        .onChange(of: arguments) { _, _ in refresh() }
        .onChange(of: runAtLoad) { _, _ in refresh() }
        .onChange(of: interval) { _, _ in refresh() }
        .onChange(of: standardOut) { _, _ in refresh() }
        .onChange(of: standardError) { _, _ in refresh() }
    }

    private func field(_ title: String, _ text: Binding<String>) -> some View {
        TextField(title, text: text)
            .textFieldStyle(.roundedBorder)
    }

    private func refresh() {
        let job = LaunchdJob(
            label: label,
            program: program,
            arguments: arguments,
            runAtLoad: runAtLoad,
            startInterval: Int(interval) ?? 0,
            standardOut: standardOut,
            standardError: standardError
        )
        let result = LaunchdBuilder.plist(job)
        output = result.issue?.display ?? result.output
        model.saveOptionsObject([
            "label": label, "program": program, "arguments": arguments, "run": runAtLoad,
            "interval": interval, "out": standardOut, "err": standardError,
        ], for: "launchd")
    }
}
