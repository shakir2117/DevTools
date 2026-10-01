import SwiftUI
import UniformTypeIdentifiers
import DevKitCore

final class RunGate: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func bump() -> Int {
        lock.lock()
        defer { lock.unlock() }
        value += 1
        return value
    }

    func current() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

struct TextToolView<Options: View>: View {
    @EnvironmentObject private var model: AppModel
    let toolID: String
    var sample: String
    var runToken: String
    var canSwap: Bool
    var pushedOutput: String
    var pushedInput: String
    var onSource: ((String) -> Void)?
    let transform: @Sendable (String) -> ToolResult
    @ViewBuilder var options: () -> Options

    @State private var input = ""
    @State private var output = ""
    @State private var issue: ToolIssue?
    @State private var running = false
    @State private var largeNote: String?
    @State private var largePayload: String?
    @State private var dropTargeted = false
    @State private var gate = RunGate()
    @State private var restored = false
    @State private var pinOutput = false

    init(
        toolID: String,
        sample: String,
        runToken: String,
        canSwap: Bool = true,
        pushedOutput: String = "",
        pushedInput: String = "",
        onSource: ((String) -> Void)? = nil,
        transform: @escaping @Sendable (String) -> ToolResult,
        @ViewBuilder options: @escaping () -> Options
    ) {
        self.toolID = toolID
        self.sample = sample
        self.runToken = runToken
        self.canSwap = canSwap
        self.pushedOutput = pushedOutput
        self.pushedInput = pushedInput
        self.onSource = onSource
        self.transform = transform
        self.options = options
    }

    private var source: String { largePayload ?? input }

    private var shownOutput: String {
        if output.utf8.count > 400_000 {
            return String(output.prefix(8_000)) + "\n\n… output truncated in the view. Copy or Save writes the full result."
        }
        return output
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            options()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            FittedSplit {
                pane(title: "Input", hint: ToolGuide.note(for: toolID).input, text: inputBinding, editable: largeNote == nil, drop: true, errorLine: largeNote == nil ? issue?.line : nil)
            } right: {
                pane(title: "Output", hint: ToolGuide.note(for: toolID).output, text: outputBinding, editable: false, drop: false, errorLine: nil)
            }
            statusBar
        }
        .onAppear(perform: restore)
        .onSample {
            pinOutput = false
            largePayload = nil
            largeNote = nil
            input = sample
        }
        .onChange(of: input) { _, newValue in
            pinOutput = false
            guard largePayload == nil else { return }
            model.setInput(newValue, for: toolID)
            schedule()
        }
        .onChange(of: runToken) { _, _ in
            pinOutput = false
            schedule()
        }
        .onChange(of: pushedOutput) { _, newValue in
            guard !newValue.isEmpty else { return }
            pinOutput = true
            output = newValue
            issue = nil
            running = false
        }
        .onChange(of: pushedInput) { _, newValue in
            guard !newValue.isEmpty else { return }
            largePayload = nil
            largeNote = nil
            if input != newValue { input = newValue }
        }
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { providers in
            loadDrop(providers)
        }
        .onChange(of: model.copyRequest) { _, value in
            guard value > 0 else { return }
            copy()
        }
    }

    private var inputBinding: Binding<String> {
        Binding(
            get: { largeNote ?? input },
            set: { newValue in
                largePayload = nil
                largeNote = nil
                input = newValue
            }
        )
    }

    private var outputBinding: Binding<String> {
        Binding(get: { shownOutput }, set: { _ in })
    }

    private var toolbar: some View {
        LiveGlass(cornerRadius: 14) {
        FlowRow(spacing: 8, lineSpacing: 8) {
            GlassIconButton(title: "Paste", symbol: "doc.on.clipboard", action: paste)
            GlassIconButton(title: "Copy", symbol: "doc.on.doc", action: copy)
            GlassIconButton(title: "Clear", symbol: "trash", action: clear)
            if canSwap {
                GlassIconButton(title: "Swap", symbol: "arrow.left.arrow.right", action: swap)
            }
            GlassIconButton(title: "Sample", symbol: "text.badge.plus") {
                largePayload = nil
                largeNote = nil
                input = sample
            }
            GlassIconButton(title: "Open", symbol: "folder", action: openFile)
            GlassIconButton(title: "Save", symbol: "square.and.arrow.down", action: saveFile)
            if running {
                ProgressView()
                    .controlSize(.small)
                Button("Cancel") { _ = gate.bump(); running = false }
                    .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func pane(title: String, hint: String, text: Binding<String>, editable: Bool, drop: Bool, errorLine: Int?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(hint)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            CodePane(text: text, editable: editable, errorLine: errorLine)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(drop && dropTargeted ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: drop && dropTargeted ? 2 : 1)
                )
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
    }

    @ViewBuilder
    private var statusBar: some View {
        if let issue {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(issue.display)
                    .lineLimit(2)
                Spacer()
            }
            .font(.callout)
            .foregroundStyle(.red)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.red.opacity(0.08))
        }
    }

    private func restore() {
        guard !restored else { return }
        restored = true
        if let saved = model.blob(for: toolID).input {
            input = saved
        }
        schedule()
    }

    private func schedule() {
        if pinOutput { return }
        let generation = gate.bump()
        let text = source
        let work = transform
        onSource?(text)
        let heavy = text.utf8.count > 250_000
        if heavy { running = true }
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.2) {
            guard generation == gate.current() else { return }
            let result = work(text)
            DispatchQueue.main.async {
                guard generation == gate.current() else { return }
                output = result.output
                issue = result.issue
                running = false
            }
        }
    }

    private func paste() {
        let board = NSPasteboard.general.string(forType: .string) ?? ""
        largePayload = nil
        largeNote = nil
        input = board
    }

    private func copy() {
        guard !output.isEmpty else {
            model.flash("Nothing to copy")
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(output, forType: .string)
        model.flash("Copied")
    }

    private func clear() {
        _ = gate.bump()
        pinOutput = false
        input = ""
        output = ""
        issue = nil
        largePayload = nil
        largeNote = nil
        running = false
        model.setInput("", for: toolID)
    }

    private func swap() {
        let next = output
        largePayload = nil
        largeNote = nil
        input = next
    }

    private func openFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.text, .plainText, .json, .xml, .sourceCode, .data]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        load(url: url)
    }

    private func saveFile() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "output.txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            guard let data = output.data(using: .utf8) else { return }
            try data.write(to: url)
            model.flash("Saved")
        } catch {
            issue = ToolIssue(message: error.localizedDescription)
        }
    }

    private func load(url: URL) {
        do {
            let data = try Data(contentsOf: url)
            if data.contains(0) {
                issue = ToolIssue(message: "\(url.lastPathComponent) looks like binary data.")
                return
            }
            let text = String(decoding: data, as: UTF8.self)
            if data.count > 400_000 {
                largePayload = text
                largeNote = "\(url.lastPathComponent) · \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)). Editing is disabled so the window stays responsive."
                input = ""
                model.setInput(nil, for: toolID)
            } else {
                largePayload = nil
                largeNote = nil
                input = text
            }
            schedule()
        } catch {
            issue = ToolIssue(message: error.localizedDescription)
        }
    }

    private func loadDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let url: URL?
            if let direct = item as? URL {
                url = direct
            } else if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else {
                url = nil
            }
            guard let url else { return }
            DispatchQueue.main.async { load(url: url) }
        }
        return true
    }
}
