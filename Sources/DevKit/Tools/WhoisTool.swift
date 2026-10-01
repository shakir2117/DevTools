import SwiftUI
import DevKitCore

struct WhoisTool: Tool {
    let id = "whois"
    let name = "WHOIS"
    let summary = "Query port 43, follow referrals, and show parsed fields"
    let symbol = "person.text.rectangle"
    let category = ToolCategory.networking
    func makeView() -> AnyView { AnyView(WhoisToolView()) }
}

struct WhoisToolView: View {
    @State private var query = "example.com"
    @State private var output = ""
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Domain or IP", text: $query)
                Button(busy ? "Querying…" : "Lookup") { lookup() }.disabled(busy)
            }
            CodePane(text: .constant(output), editable: false)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .copyOutput { output }
        .onSample { query = "example.com" }
    }

    private func lookup() {
        busy = true
        let query = query
        Task {
            let result = await WhoisClient.lookup(query)
            await MainActor.run {
                output = result.issue?.message ?? result.output
                busy = false
            }
        }
    }
}
