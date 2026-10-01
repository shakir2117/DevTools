import SwiftUI
import DevKitCore

struct CronTool: Tool {
    let id = "cron"
    let name = "Crontab"
    let summary = "Build, explain, and preview the next runs of a 5-field cron"
    let symbol = "calendar.badge.clock"
    let category = ToolCategory.generators
    func makeView() -> AnyView { AnyView(CronToolView()) }
}

struct CronToolView: View {
    @EnvironmentObject private var model: AppModel
    @State private var minute = "0"
    @State private var hour = "0"
    @State private var day = "*"
    @State private var month = "*"
    @State private var weekday = "*"
    @State private var expression = "0 0 * * *"
    @State private var output = ""
    @State private var issue: ToolIssue?
    @State private var restored = false
    @State private var writing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                field("Minute", $minute)
                field("Hour", $hour)
                field("Day", $day)
                field("Month", $month)
                field("Weekday", $weekday)
                Button("Build") { expression = Cron.build(minute: minute, hour: hour, day: day, month: month, weekday: weekday) }
            }
            TextField("Expression", text: $expression)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
            Text(output)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .textSelection(.enabled)
            if let issue { Text(issue.display).foregroundStyle(.red) }
        }
        .padding(12)
        .onAppear {
            guard !restored else { return }
            restored = true
            expression = model.loadOptionsObject(for: "cron")["expression"] as? String ?? expression
            evaluate()
        }
        .onChange(of: expression) { _, _ in
            evaluate()
            model.saveOptionsObject(["expression": expression], for: "cron")
        }
    }

    private func field(_ title: String, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField(title, text: text).frame(width: 70)
        }
    }

    private func evaluate() {
        let result = Cron.explain(expression)
        output = result.output
        issue = result.issue
    }
}
