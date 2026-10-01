import SwiftUI
import DevKitCore

struct TLSTool: Tool {
    let id = "tls"
    let name = "TLS Certificate"
    let summary = "Inspect the chain, trust result, fingerprints, and PEM"
    let symbol = "lock.shield"
    let category = ToolCategory.networking
    func makeView() -> AnyView { AnyView(TLSToolView()) }
}

struct TLSToolView: View {
    @State private var host = "example.com"
    @State private var port = "443"
    @State private var output = ""
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Host", text: $host)
                TextField("Port", text: $port).frame(width: 80)
                Button(busy ? "Connecting…" : "Inspect") { inspect() }.disabled(busy)
            }
            TextEditor(text: .constant(output))
                .font(.system(.body, design: .monospaced))
        }
        .padding(12)
    }

    private func inspect() {
        busy = true
        let host = host
        let port = Int(port) ?? 443
        Task {
            let result = await TLSInspect.inspect(host: host, port: port)
            await MainActor.run {
                output = result.issue?.message ?? result.output
                busy = false
            }
        }
    }
}
