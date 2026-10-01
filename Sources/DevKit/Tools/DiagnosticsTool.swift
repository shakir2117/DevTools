import SwiftUI
import DevKitCore

struct DiagnosticsTool: Tool {
    let id = "diagnostics"
    let name = "Network Diagnostics"
    let summary = "DNS, TCP, HTTP timing, path status, local IPs, and ping"
    let symbol = "waveform.path.ecg"
    let category = ToolCategory.networking
    func makeView() -> AnyView { AnyView(DiagnosticsToolView()) }
}

struct DiagnosticsToolView: View {
    @State private var host = "example.com"
    @State private var samples = 3
    @State private var output = ""
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Host", text: $host)
                Stepper("Ping samples \(samples)", value: $samples, in: 1...10)
                Button(busy ? "Running…" : "Run") { run() }.disabled(busy)
            }
            CodePane(text: .constant(output), editable: false)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .copyOutput { output }
        .onSample { host = "example.com"; samples = 3 }
    }

    private func run() {
        busy = true
        let host = host
        let samples = samples
        Task {
            let text = await NetDiagnostics.run(host: host, samples: samples)
            await MainActor.run {
                output = text
                busy = false
            }
        }
    }
}
