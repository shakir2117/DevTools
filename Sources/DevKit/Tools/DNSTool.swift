import SwiftUI
import DevKitCore

struct DNSTool: Tool {
    let id = "dns"
    let name = "DNS Lookup"
    let summary = "Query A through CAA with dig or DNS over HTTPS"
    let symbol = "globe"
    let category = ToolCategory.networking
    func makeView() -> AnyView { AnyView(DNSToolView()) }
}

struct DNSToolView: View {
    @State private var name = "example.com"
    @State private var type = "A"
    @State private var doh = false
    @State private var output = ""
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Name", text: $name)
                Picker("Type", selection: $type) {
                    ForEach(DNSLookup.types, id: \.self) { Text($0).tag($0) }
                }
                .frame(width: 120)
                Picker("Resolver", selection: $doh) {
                    Text("System dig").tag(false)
                    Text("DoH").tag(true)
                }
                .frame(width: 180)
                Button(busy ? "Looking…" : "Lookup") { lookup() }.disabled(busy)
            }
            TextEditor(text: .constant(output))
                .font(.system(.body, design: .monospaced))
        }
        .padding(12)
    }

    private func lookup() {
        busy = true
        let name = name
        let type = type
        let doh = doh
        DispatchQueue.global(qos: .userInitiated).async {
            let result = DNSLookup.lookup(name: name, type: type, useDoH: doh)
            DispatchQueue.main.async {
                output = result.issue?.message ?? result.output
                busy = false
            }
        }
    }
}
