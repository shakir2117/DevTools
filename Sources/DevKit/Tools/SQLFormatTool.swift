import SwiftUI
import DevKitCore

struct SQLFormatTool: Tool {
    let id = "sql-format"
    let name = "SQL Formatter"
    let summary = "Pretty-print a query and list the tables it names"
    let symbol = "text.word.spacing"
    let category = ToolCategory.formatters
    func makeView() -> AnyView { AnyView(SQLFormatToolView()) }
}

struct SQLFormatToolView: View {
    var body: some View {
        TextToolView(
            toolID: "sql-format",
            sample: "select id from users join orders on orders.user_id = users.id where id = 1",
            runToken: "sql",
            canSwap: false,
            transform: { SQLFormat.format($0) }
        ) {
            EmptyView()
        }
    }
}
