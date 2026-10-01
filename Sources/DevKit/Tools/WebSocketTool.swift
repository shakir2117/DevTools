import SwiftUI

struct WebSocketTool: Tool {
    let id = "websocket"
    let name = "WebSocket"
    let summary = "Connect, send text or binary, and log frames"
    let symbol = "wave.3.right"
    let category = ToolCategory.networking
    func makeView() -> AnyView { AnyView(WebSocketToolView()) }
}

struct WebSocketToolView: View {
    @StateObject private var client = WebSocketClient()
    @State private var url = "wss://echo.websocket.events"
    @State private var headerName = ""
    @State private var headerValue = ""
    @State private var message = "hello"
    @State private var binary = false
    @State private var reconnect = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("ws:// or wss://", text: $url)
                Toggle("Reconnect", isOn: $reconnect)
                Button(client.connected ? "Disconnect" : "Connect") {
                    if client.connected { client.disconnect() } else { client.connect(url: url, headers: client.headers, reconnect: reconnect) }
                }
            }
            HStack {
                TextField("Header", text: $headerName)
                TextField("Value", text: $headerValue)
                Button("Add") {
                    client.headers.append((headerName, headerValue))
                    headerName = ""
                    headerValue = ""
                }
            }
            Text(client.headers.map { "\($0.0): \($0.1)" }.joined(separator: "  "))
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                TextField(binary ? "Base64 payload" : "Message", text: $message)
                Toggle("Binary", isOn: $binary)
                Button("Send") { client.send(message, binary: binary) }.disabled(!client.connected)
            }
            TextEditor(text: .constant(client.log))
                .font(.system(.body, design: .monospaced))
        }
        .padding(12)
        .onDisappear { client.disconnect() }
    }
}

final class WebSocketClient: ObservableObject {
    @Published var log = ""
    @Published var connected = false
    var headers: [(String, String)] = []
    private var task: URLSessionWebSocketTask?
    private var session: URLSession?
    private var shouldReconnect = false
    private var url: URL?
    private var generation = 0

    func connect(url: String, headers: [(String, String)], reconnect: Bool) {
        guard let endpoint = URL(string: url), endpoint.scheme == "ws" || endpoint.scheme == "wss" else {
            append("Enter a ws:// or wss:// URL.")
            return
        }
        disconnect()
        self.url = endpoint
        shouldReconnect = reconnect
        generation += 1
        let current = generation
        var request = URLRequest(url: endpoint)
        for header in headers where !header.0.isEmpty {
            request.setValue(header.1, forHTTPHeaderField: header.0)
        }
        let session = URLSession(configuration: .default)
        self.session = session
        let task = session.webSocketTask(with: request)
        self.task = task
        task.resume()
        connected = true
        append("Connecting \(endpoint.absoluteString)")
        receive(generation: current)
    }

    func disconnect() {
        shouldReconnect = false
        generation += 1
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        session?.invalidateAndCancel()
        session = nil
        connected = false
    }

    func send(_ text: String, binary: Bool) {
        let message: URLSessionWebSocketTask.Message
        if binary {
            guard let data = Data(base64Encoded: text) else {
                append("Binary send expects Base64.")
                return
            }
            message = .data(data)
        } else {
            message = .string(text)
        }
        task?.send(message) { [weak self] error in
            DispatchQueue.main.async {
                if let error { self?.append("Send failed: \(error.localizedDescription)") }
                else { self?.append("Sent \(binary ? "binary" : "text")") }
            }
        }
    }

    private func receive(generation: Int) {
        task?.receive { [weak self] result in
            DispatchQueue.main.async {
                guard let self, generation == self.generation else { return }
                switch result {
                case let .success(message):
                    switch message {
                    case let .string(text): self.append("← \(text)")
                    case let .data(data): self.append("← binary \(data.base64EncodedString())")
                    @unknown default: self.append("← unknown frame")
                    }
                    self.receive(generation: generation)
                case let .failure(error):
                    self.append("Closed: \(error.localizedDescription)")
                    self.connected = false
                    if self.shouldReconnect, let url = self.url {
                        self.append("Reconnecting…")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            guard generation == self.generation else { return }
                            self.connect(url: url.absoluteString, headers: self.headers, reconnect: true)
                        }
                    }
                }
            }
        }
    }

    private func append(_ line: String) {
        let stamp = ISO8601DateFormatter().string(from: Date())
        log = "[\(stamp)] \(line)\n" + log
    }
}
