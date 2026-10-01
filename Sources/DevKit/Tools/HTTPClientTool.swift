import SwiftUI
import DevKitCore

struct HTTPClientTool: Tool {
    let id = "http-client"
    let name = "HTTP Client"
    let summary = "Methods, headers, bodies, auth, history, and environment variables"
    let symbol = "paperplane"
    let category = ToolCategory.networking
    func makeView() -> AnyView { AnyView(HTTPClientToolView()) }
}

private struct HTTPHistoryItem: Codable, Hashable, Identifiable {
    var id: String
    var method: String
    var url: String
    var summary: String

    var label: String {
        let status = summary.split(separator: "\n").first.map(String.init) ?? ""
        if status.isEmpty { return "\(method) \(url)" }
        return "\(method) \(url) — \(status)"
    }
}

private struct HTTPSavedRequest: Codable, Identifiable {
    var id: String { name }
    var name: String
    var method: String
    var url: String
    var query: [HTTPField]
    var headers: [HTTPField]
    var bodyKind: String
    var body: String
    var form: [HTTPField]
    var auth: String
    var authValue: String
    var authSecret: String
    var follow: Bool
    var timeout: Double
    var envText: String
}

struct HTTPClientToolView: View {
    @EnvironmentObject private var model: AppModel
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
    @State private var history: [HTTPHistoryItem] = []
    @State private var historyPick = ""
    @State private var collections: [HTTPSavedRequest] = []
    @State private var collectionName = "default"
    @State private var savedPick = ""
    @State private var busy = false
    @State private var restored = false

    private let methods = ["GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS"]
    private let historyKey = "devkit.http.history.v2"
    private let collectionsKey = "devkit.http.collections"

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
                CodePane(text: $rawBody)
                    .frame(height: 120)
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
                TextField("Collection name", text: $collectionName)
                Button("Save") { saveCollection() }
                Button("Load") { loadCollection() }
                Button("Delete") { deleteCollection() }
                    .disabled(collections.contains { $0.name == collectionName } == false)
                Picker("Saved", selection: $savedPick) {
                    Text("Choose").tag("")
                    ForEach(collections) { item in
                        Text(item.name).tag(item.name)
                    }
                }
                .frame(maxWidth: 180)
            }
            if !history.isEmpty {
                Picker("History", selection: $historyPick) {
                    Text("History").tag("")
                    ForEach(history) { item in
                        Text(item.label).tag(item.id)
                    }
                }
            }
            Text(summary).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
            CodePane(text: .constant(responseBody), editable: false)
                .frame(minHeight: 160)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear(perform: restore)
        .onSample {
            method = "POST"
            url = "https://example.com/api"
            query = [HTTPField(name: "q", value: "1")]
            headers = [HTTPField(name: "Content-Type", value: "application/json")]
            bodyKind = "raw"
            rawBody = "{\"a\":1}"
            auth = "none"
        }
        .onChange(of: method) { _, _ in persistRequest() }
        .onChange(of: url) { _, _ in persistRequest() }
        .onChange(of: query) { _, _ in persistRequest() }
        .onChange(of: headers) { _, _ in persistRequest() }
        .onChange(of: bodyKind) { _, _ in persistRequest() }
        .onChange(of: rawBody) { _, _ in persistRequest() }
        .onChange(of: form) { _, _ in persistRequest() }
        .onChange(of: auth) { _, _ in persistRequest() }
        .onChange(of: authValue) { _, _ in persistRequest() }
        .onChange(of: authSecret) { _, _ in persistRequest() }
        .onChange(of: follow) { _, _ in persistRequest() }
        .onChange(of: timeout) { _, _ in persistRequest() }
        .onChange(of: envText) { _, _ in persistRequest() }
        .onChange(of: historyPick) { _, id in
            guard let item = history.first(where: { $0.id == id }) else { return }
            method = item.method
            url = item.url
        }
        .onChange(of: savedPick) { _, name in
            guard !name.isEmpty else { return }
            collectionName = name
            loadCollection()
        }
        .copyOutput { responseBody.isEmpty ? summary : responseBody }
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
        let sentMethod = method
        let sentURL = url
        Task {
            let report = await HTTPClientCore.send(spec)
            await MainActor.run {
                summary = report.summary
                responseBody = report.body
                busy = false
                let item = HTTPHistoryItem(id: UUID().uuidString, method: sentMethod, url: sentURL, summary: report.summary)
                history.removeAll { $0.method == sentMethod && $0.url == sentURL }
                history.insert(item, at: 0)
                history = Array(history.prefix(20))
                storeHistory()
                persistRequest()
            }
        }
    }

    private func currentRequest(name: String) -> HTTPSavedRequest {
        var body = rawBody
        if body.utf8.count > 200_000 { body = String(body.prefix(200_000)) }
        return HTTPSavedRequest(
            name: name,
            method: method,
            url: url,
            query: query,
            headers: headers,
            bodyKind: bodyKind,
            body: body,
            form: form,
            auth: auth,
            authValue: authValue,
            authSecret: authSecret,
            follow: follow,
            timeout: timeout,
            envText: envText
        )
    }

    private func apply(_ saved: HTTPSavedRequest) {
        method = saved.method
        url = saved.url
        query = saved.query
        headers = saved.headers
        bodyKind = saved.bodyKind
        rawBody = saved.body
        form = saved.form.isEmpty ? [HTTPField()] : saved.form
        auth = saved.auth
        authValue = saved.authValue
        authSecret = saved.authSecret
        follow = saved.follow
        timeout = saved.timeout
        envText = saved.envText
    }

    private func saveCollection() {
        let name = collectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            model.flash("Name the collection")
            return
        }
        let item = currentRequest(name: name)
        if let index = collections.firstIndex(where: { $0.name == name }) {
            collections[index] = item
        } else {
            collections.append(item)
        }
        storeCollections()
        savedPick = name
        model.flash("Saved \(name)")
    }

    private func loadCollection() {
        let name = collectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let saved = collections.first(where: { $0.name == name }) else {
            summary = "No collection named \(name)."
            return
        }
        apply(saved)
        summary = "Loaded \(name)."
    }

    private func deleteCollection() {
        let name = collectionName
        collections.removeAll { $0.name == name }
        if savedPick == name { savedPick = "" }
        storeCollections()
        model.flash("Deleted \(name)")
    }

    private func restore() {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let decoded = try? JSONDecoder().decode([HTTPHistoryItem].self, from: data) {
            history = decoded
        } else if let urls = UserDefaults.standard.stringArray(forKey: "devkit.http.history") {
            history = urls.map { HTTPHistoryItem(id: UUID().uuidString, method: "GET", url: $0, summary: "") }
        }
        if let data = UserDefaults.standard.data(forKey: collectionsKey),
           let decoded = try? JSONDecoder().decode([HTTPSavedRequest].self, from: data) {
            collections = decoded
        }
        if let raw = model.blob(for: "http-client").options,
           let data = raw.data(using: .utf8),
           let saved = try? JSONDecoder().decode(HTTPSavedRequest.self, from: data) {
            apply(saved)
        }
        restored = true
    }

    private func persistRequest() {
        guard restored else { return }
        guard let data = try? JSONEncoder().encode(currentRequest(name: "last")),
              let json = String(data: data, encoding: .utf8) else { return }
        model.setOptions(json, for: "http-client")
    }

    private func storeHistory() {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }

    private func storeCollections() {
        if let data = try? JSONEncoder().encode(collections) {
            UserDefaults.standard.set(data, forKey: collectionsKey)
        }
    }
}
