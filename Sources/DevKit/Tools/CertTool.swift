import SwiftUI
import UniformTypeIdentifiers
import DevKitCore

struct CertTool: Tool {
    let id = "certificate"
    let name = "Certificate Viewer"
    let summary = "PEM certificate or CSR: subject, SANs, and expiry"
    let symbol = "lock.doc"
    let category = ToolCategory.inspection
    func makeView() -> AnyView { AnyView(CertToolView()) }
}

struct CertToolView: View {
    @State private var fileNote = ""
    @State private var pushedOutput = ""

    var body: some View {
        TextToolView(
            toolID: "certificate",
            sample: "-----BEGIN CERTIFICATE-----\n",
            runToken: "certificate",
            canSwap: false,
            pushedOutput: pushedOutput,
            transform: { CertInspect.describe(pem: $0) }
        ) {
            FlowRow(spacing: 10, lineSpacing: 8) {
                Button("Open PEM or DER…") { openFile() }
                    .fixedSize()
                if !fileNote.isEmpty {
                    Text(fileNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: 280, alignment: .leading)
                }
            }
        }
    }

    private func openFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.data, .x509Certificate]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        fileNote = "Reading \(url.lastPathComponent)…"
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Self.load(url)
            DispatchQueue.main.async {
                if let issue = result.issue {
                    fileNote = issue.message
                } else {
                    pushedOutput = result.output
                    fileNote = "Read \(url.lastPathComponent)."
                }
            }
        }
    }

    private static func load(_ url: URL) -> ToolResult {
        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values.isRegularFile == true else { return .failure("Choose a regular file.") }
            guard let size = values.fileSize, size <= 1_000_000 else { return .failure("File is larger than 1 MB.") }
            return CertInspect.describe(data: try Data(contentsOf: url))
        } catch {
            return .failure(error.localizedDescription)
        }
    }
}
