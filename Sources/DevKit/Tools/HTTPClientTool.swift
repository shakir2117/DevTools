import SwiftUI
import DevKitCore

struct HTTPClientTool: Tool {
    let id = "http-client"
    let name = "HTTP Client"
    let summary = "Methods, headers, bodies, auth, history, and environment variables"
    let symbol = "network"
    let category = ToolCategory.networking
    func makeView() -> AnyView { AnyView(HTTPClientToolView()) }
}

struct HTTPClientToolView: View {
    @State private var method = "GET"
    @State private var url = "https://example.com"
    @State private var queryName = ""
    @State private var queryValue = ""
    @State private var query: [HTTPField] = []
    @State private var headerName = ""
    @State private var headerValue = ""
    @State private var headers: [HTTPField] = []
    @State private var bodyKind = "none"
    @State private var rawBody = ""
    @State private var form: [HTTPField] = [HTTPField(name: "", value: "")]
    @State private var auth = "none"
    @State private var authValue = ""
    @State private var authSecret = ""
    @State private var follow = true
    @State private var timeout = 30.0
    @State private var envText = "host=example.com"
    @State private var summary = ""
    @State private var responseBody = ""
    @State private var history: [String] = []
    @State private var collectionName = "default"
    @State private var busy = false

    private let methods = ["GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Picker("Method", selection: $method) {
                    ForEach(methods, id: \.self) { Text($0).tag($0) }
                }
                .frame(width: 120)
                TextField("URL, {{env}} allowed", text: $url)
                Toggle("Redirects", isOn: $follow)
                Button(busy ? "Sending…" : "Send") { send() }.disabled(busy)
            }
            HStack {
                TextField("Query name", text: $queryName)
                TextField("Value", text: $queryValue)
                Button("Add query") { query.append(HTTPField(name: queryName, value: queryValue)); queryName = ""; queryValue = "" }
                TextField("Header", text: $headerName)
                TextField("Value", text: $headerValue)
                Button("Add header") { headers.append(HTTPField(name: headerName, value: headerValue)); headerName = ""; headerValue = "" }
            }
            HStack {
                Picker("Body", selection: $bodyKind) {
                    Text("None").tag("none"); Text("Raw").tag("raw"); Text("Form").tag("form"); Text("Multipart").tag("multipart")
                }
                .frame(width: 280)
                Picker("Auth", selection: $auth) {
                    Text("None").tag("none"); Text("Basic").tag("basic"); Text("Bearer").tag("bearer"); Text("API key").tag("apikey")
                }
                .frame(width: 220)
                TextField(auth == "basic" ? "User" : "Token", text: $authValue)
                TextField(auth == "apikey" ? "Header name" : "Secret", text: $authSecret)
            }
            if bodyKind == "raw" {
                TextEditor(text: $rawBody).font(.system(.body, design: .monospaced)).frame(height: 70)
            }
            if bodyKind == "form" || bodyKind == "multipart" {
                ForEach(form.indices, id: \.self) { index in
                    HStack {
                        TextField("Name", text: $form[index].name)
                        TextField("Value", text: $form[index].value)
                    }
                }
                Button("Add field") { form.append(HTTPField()) }
            }
            TextField("Environment name=value, one per line", text: $envText, axis: .vertical).lineLimit(2...4)
            HStack {
                TextField("Collection", text: $collectionName)
                Button("Save") { saveCollection() }
                Button("Load") { loadCollection() }
                if !history.isEmpty {
                    Picker("History", selection: $url) {
                        ForEach(history, id: \.self) { Text($0).tag($0) }
                    }
                    .frame(maxWidth: 260)
                }
            }
            Text(summary).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
            TextEditor(text: .constant(responseBody))
                .font(.system(.body, design: .monospaced))
        }
        .padding(12)
        .onAppear { history = UserDefaults.standard.stringArray(forKey: "devkit.http.history") ?? [] }
    }

    private func environment() -> [String: String] {
        var values: [String: String] = [:]
        for line in envText.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
            if parts.count == 2 { values[parts[0].trimmingCharacters(in: .whitespaces)] = parts[1] }
        }
        return values
    }

    private func send() {
        busy = true
        let spec = HTTPSpec(method: method, url: url, query: query, headers: headers, bodyKind: bodyKind, body: rawBody, form: form, auth: auth, authValue: authValue, authSecret: authSecret, followRedirects: follow, timeout: timeout, environment: environment())
        Task {
            let report = await HTTPClientCore.send(spec)
            await MainActor.run {
                summary = report.summary
                responseBody = report.body
                busy = false
                history.removeAll { $0 == url }
                history.insert(url, at: 0)
                history = Array(history.prefix(20))
                UserDefaults.standard.set(history, forKey: "devkit.http.history")
            }
        }
    }

    private func saveCollection() {
        let payload: [String: String] = ["method": method, "url": url, "bodyKind": bodyKind, "body": rawBody, "auth": auth]
        UserDefaults.standard.set(payload, forKey: "devkit.http.collection.\(collectionName)")
        summary = "Saved collection \(collectionName)."
    }

    private func loadCollection() {
        guard let payload = UserDefaults.standard.dictionary(forKey: "devkit.http.collection.\(collectionName)") as? [String: String] else {
            summary = "No collection named \(collectionName)."
            return
        }
        method = payload["method"] ?? method
        url = payload["url"] ?? url
        bodyKind = payload["bodyKind"] ?? bodyKind
        rawBody = payload["body"] ?? rawBody
        auth = payload["auth"] ?? auth
    }
}
