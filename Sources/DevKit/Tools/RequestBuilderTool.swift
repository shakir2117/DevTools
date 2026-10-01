import SwiftUI
import DevKitCore

struct RequestBuilderTool: Tool {
    let id = "request-builder"
    let name = "Request Builder"
    let summary = "Split a curl command into URL, headers, and body, then send it"
    let symbol = "slider.horizontal.3"
    let category = ToolCategory.networking
    func makeView() -> AnyView { AnyView(RequestBuilderToolView()) }
}

private struct PartRow: Identifiable, Equatable {
    var id = UUID()
    var name = ""
    var value = ""

    init() {}

    init(_ field: HTTPField) {
        name = field.name
        value = field.value
    }

    var field: HTTPField { HTTPField(name: name, value: value) }
}

struct RequestBuilderToolView: View {
    @EnvironmentObject private var model: AppModel
    @State private var curl = "curl -X POST 'https://example.com/api?q=1' -H 'Content-Type: application/json' -H 'Accept: application/json' -d '{\"a\":1}'"
    @State private var method = "POST"
    @State private var url = "https://example.com/api"
    @State private var query: [PartRow] = [PartRow(HTTPField(name: "q", value: "1"))]
    @State private var headers: [PartRow] = [
        PartRow(HTTPField(name: "Content-Type", value: "application/json")),
        PartRow(HTTPField(name: "Accept", value: "application/json")),
    ]
    @State private var requestBody = "{\"a\":1}"
    @State private var auth = "none"
    @State private var authValue = ""
    @State private var authSecret = ""
    @State private var follow = false
    @State private var note = ""
    @State private var statusLine = ""
    @State private var responseHeaders = ""
    @State private var responseBody = ""
    @State private var busy = false
    @State private var restored = false
    @State private var importedCurl = ""

    private let methods = ["GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                block("Import", hint: "Paste a valid curl command and the method, URL, query, headers, and body fill in. TLS verification stays on.") {
                    TextField("curl …", text: $curl, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(2...5)
                    FlowRow(spacing: 8, lineSpacing: 8) {
                        Button("Import") { importCurl() }.fixedSize()
                        Button("Sample") { useSample() }.fixedSize()
                        if !note.isEmpty {
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: 420, alignment: .leading)
                        }
                    }
                }
                block("Request", hint: "Change the method or URL, then send. Only http and https are sent.") {
                    FlowRow(spacing: 8, lineSpacing: 8) {
                        Picker("Method", selection: $method) {
                            ForEach(methods, id: \.self) { Text($0).tag($0) }
                        }
                        .frame(width: 120)
                        TextField("https://example.com/api", text: $url)
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 180, maxWidth: .infinity)
                        Toggle("Redirects", isOn: $follow).fixedSize()
                        Button(busy ? "Sending…" : "Send") { send() }
                            .disabled(busy)
                            .fixedSize()
                    }
                }
                block("Auth", hint: "Basic uses the user and password. Bearer sends Authorization: Bearer, once.") {
                    FlowRow(spacing: 8, lineSpacing: 8) {
                        Picker("Auth", selection: $auth) {
                            Text("None").tag("none")
                            Text("Basic").tag("basic")
                            Text("Bearer").tag("bearer")
                        }
                        .frame(width: 140)
                        TextField(auth == "basic" ? "User" : "Token", text: $authValue)
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 120, maxWidth: 240)
                        if auth == "basic" {
                            SecureField("Password", text: $authSecret)
                                .textFieldStyle(.roundedBorder)
                                .frame(minWidth: 120, maxWidth: 240)
                        }
                    }
                }
                block("Query", hint: "These are added to the URL when you send. The URL box stays without the query string.") {
                    rows($query, namePrompt: "Name", valuePrompt: "Value", addTitle: "Add query")
                }
                block("Headers", hint: "One header per row. A name cannot contain a colon or a line break.") {
                    rows($headers, namePrompt: "Header", valuePrompt: "Value", addTitle: "Add header")
                }
                block("Body", hint: "Sent as the request body. Leave it empty for GET.") {
                    CodePane(text: $requestBody)
                        .frame(minHeight: 120, maxHeight: 180)
                }
                block("Response", hint: "Status, response headers, and body stay in separate sections.") {
                    Text(statusLine.isEmpty ? "Send a request to fill this in." : statusLine)
                        .font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Response headers")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    CodePane(text: .constant(responseHeaders), editable: false)
                        .frame(minHeight: 100, maxHeight: 160)
                    Text("Response body")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    CodePane(text: .constant(responseBody), editable: false)
                        .frame(minHeight: 140, maxHeight: 280)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear(perform: restore)
        .onSample { useSample() }
        .onChange(of: curl) { old, new in
            persist()
            guard restored, pasted(old, new) else { return }
            importIfValid(new)
        }
        .onChange(of: method) { _, _ in persist() }
        .onChange(of: url) { _, _ in persist() }
        .onChange(of: query) { _, _ in persist() }
        .onChange(of: headers) { _, _ in persist() }
        .onChange(of: requestBody) { _, _ in persist() }
        .onChange(of: auth) { _, _ in persist() }
        .onChange(of: authValue) { _, _ in persist() }
        .onChange(of: authSecret) { _, _ in persist() }
        .onChange(of: follow) { _, _ in persist() }
        .copyOutput { responseBody.isEmpty ? statusLine : responseBody }
    }

    private func block<Content: View>(_ title: String, hint: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(hint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func rows(_ rows: Binding<[PartRow]>, namePrompt: String, valuePrompt: String, addTitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(rows) { $row in
                HStack(spacing: 8) {
                    TextField(namePrompt, text: $row.name)
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 80, maxWidth: .infinity)
                    TextField(valuePrompt, text: $row.value)
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 80, maxWidth: .infinity)
                    Button {
                        rows.wrappedValue.removeAll { $0.id == row.id }
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .fixedSize()
                }
            }
            Button(addTitle) { rows.wrappedValue.append(PartRow()) }
                .fixedSize()
        }
    }

    private func useSample() {
        curl = "curl -X POST 'https://example.com/api?q=1' -H 'Content-Type: application/json' -H 'Accept: application/json' -d '{\"a\":1}'"
        importCurl()
    }

    private func pasted(_ old: String, _ new: String) -> Bool {
        if new == old { return false }
        return abs(new.count - old.count) > 1
    }

    private func importIfValid(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != importedCurl else { return }
        switch CurlTranslate.request(trimmed) {
        case let .success(spec):
            apply(spec)
            note = "Imported \(spec.method) \(spec.url)."
        case let .failure(issue):
            if trimmed.lowercased().hasPrefix("curl") {
                note = issue.message
            }
        }
    }

    private func importCurl() {
        switch CurlTranslate.request(curl) {
        case let .failure(issue):
            note = issue.message
        case let .success(spec):
            apply(spec)
            note = "Imported \(spec.method) \(spec.url)."
        }
    }

    private func apply(_ spec: HTTPSpec) {
        method = spec.method
        url = spec.url
        query = spec.query.map(PartRow.init)
        headers = spec.headers.map(PartRow.init)
        requestBody = spec.body
        auth = spec.auth
        authValue = spec.authValue
        authSecret = spec.authSecret
        follow = spec.followRedirects
        importedCurl = curl.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func send() {
        let trimmed = requestBody.trimmingCharacters(in: .whitespacesAndNewlines)
        let spec = HTTPSpec(
            method: method,
            url: url,
            query: query.map(\.field).filter { !$0.name.isEmpty },
            headers: headers.map(\.field).filter { !$0.name.isEmpty },
            bodyKind: trimmed.isEmpty ? "none" : "raw",
            body: requestBody,
            auth: auth,
            authValue: authValue,
            authSecret: authSecret,
            followRedirects: follow,
            timeout: 30
        )
        busy = true
        note = ""
        Task {
            let report = await HTTPClientCore.send(spec)
            await MainActor.run {
                statusLine = report.statusLine.isEmpty ? report.summary : report.statusLine
                responseHeaders = report.responseHeaders
                responseBody = report.body
                busy = false
                if report.body.isEmpty, report.responseHeaders.isEmpty, !report.summary.isEmpty {
                    note = report.summary
                }
            }
        }
    }

    private func restore() {
        guard !restored else { return }
        restored = true
        let saved = model.loadOptionsObject(for: "request-builder")
        if let value = saved["curl"] as? String, !value.isEmpty { curl = value }
        if let value = saved["method"] as? String, methods.contains(value) { method = value }
        if let value = saved["url"] as? String, !value.isEmpty { url = value }
        if let value = saved["body"] as? String { requestBody = value }
        if let value = saved["auth"] as? String { auth = value }
        if let value = saved["authValue"] as? String { authValue = value }
        if let value = saved["authSecret"] as? String { authSecret = value }
        if let value = saved["follow"] as? Bool { follow = value }
        query = rows(from: saved["query"])
        headers = rows(from: saved["headers"])
        importedCurl = curl.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func rows(from value: Any?) -> [PartRow] {
        guard let pairs = value as? [[String: Any]] else { return [] }
        return pairs.map { PartRow(HTTPField(name: $0["name"] as? String ?? "", value: $0["value"] as? String ?? "")) }
    }

    private func persist() {
        guard restored else { return }
        var stored = requestBody
        if stored.utf8.count > 200_000 { stored = String(stored.prefix(200_000)) }
        model.saveOptionsObject([
            "curl": curl,
            "method": method,
            "url": url,
            "body": stored,
            "auth": auth,
            "authValue": authValue,
            "authSecret": authSecret,
            "follow": follow,
            "query": query.map { ["name": $0.name, "value": $0.value] },
            "headers": headers.map { ["name": $0.name, "value": $0.value] },
        ], for: "request-builder")
    }
}
