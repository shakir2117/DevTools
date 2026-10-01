import Foundation

public enum CurlTranslate {
    public struct Command: Equatable, Sendable {
        public var method: String
        public var url: String
        public var headers: [String]
        public var body: String
        public var user: String
        public var follow: Bool
        public var insecure: Bool
    }

    public static func parse(_ text: String) -> Result<Command, ToolIssue> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .failure(ToolIssue(message: "Paste a curl command.")) }
        if trimmed.count > 200_000 { return .failure(ToolIssue(message: "That command is too long.")) }
        var tokens = tokenize(trimmed)
        if tokens.first == "curl" { tokens.removeFirst() }
        var command = Command(method: "GET", url: "", headers: [], body: "", user: "", follow: false, insecure: false)
        var dataParts: [String] = []
        var forceGet = false
        var index = 0
        func take() -> String? {
            guard index < tokens.count else { return nil }
            let value = tokens[index]
            index += 1
            return value
        }
        while index < tokens.count {
            guard let token = take() else { break }
            switch token {
            case "-X", "--request":
                command.method = (take() ?? "GET").uppercased()
            case "-H", "--header":
                if let header = take() { command.headers.append(header) }
            case "-d", "--data", "--data-raw", "--data-binary", "--data-ascii":
                if let part = take() { dataParts.append(part) }
            case "--data-urlencode":
                if let part = take() { dataParts.append(part.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? part) }
            case "-u", "--user":
                command.user = take() ?? ""
            case "-A", "--user-agent":
                if let agent = take() { command.headers.append("User-Agent: \(agent)") }
            case "-L", "--location":
                command.follow = true
            case "-k", "--insecure":
                command.insecure = true
            case "-G", "--get":
                forceGet = true
            case "--url":
                command.url = take() ?? ""
            default:
                if token.hasPrefix("-") {
                    return .failure(ToolIssue(message: "Unsupported curl flag \(token)."))
                }
                if command.url.isEmpty { command.url = token }
            }
        }
        if command.url.isEmpty { return .failure(ToolIssue(message: "The command has no URL.")) }
        if !dataParts.isEmpty {
            command.body = dataParts.joined(separator: "&")
            if command.method == "GET" && !forceGet { command.method = "POST" }
            if forceGet {
                command.method = "GET"
                let joiner = command.url.contains("?") ? "&" : "?"
                command.url += joiner + command.body
                command.body = ""
            }
        }
        return .success(command)
    }

    public static func swiftCode(_ command: Command) -> String {
        """
        guard let url = URL(string: \(literal(command.url))) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = \(literal(command.method))
        \(headerLines(command, style: .swift))
        \(command.body.isEmpty ? "" : "request.httpBody = Data(\(literal(command.body)).utf8)")
        let (data, response) = try await URLSession.shared.data(for: request)
        """
    }

    public static func python(_ command: Command) -> String {
        let headerPairs = command.headers.map { pair -> String in
            let bits = splitHeader(pair)
            return "\(literal(bits.0)): \(literal(bits.1))"
        }.joined(separator: ", ")
        let headers = command.headers.isEmpty ? "" : "headers={\(headerPairs)}, "
        let data = command.body.isEmpty ? "" : "data=\(literal(command.body)), "
        let auth = command.user.isEmpty ? "" : "auth=\(pythonAuth(command.user)), "
        return "import requests\nresponse = requests.\(command.method.lowercased())(\(literal(command.url)), \(headers)\(data)\(auth)\(command.follow ? "" : "allow_redirects=False, "))\nprint(response.status_code)\nprint(response.text)"
    }

    public static func javascript(_ command: Command) -> String {
        """
        const response = await fetch(\(literal(command.url)), {
          method: \(literal(command.method)),
          headers: {\(jsHeaders(command))},
          \(command.body.isEmpty ? "" : "body: \(literal(command.body)),")
          redirect: \(literal(command.follow ? "follow" : "manual"))
        });
        console.log(response.status, await response.text());
        """
    }

    public static func goCode(_ command: Command) -> String {
        """
        req, err := http.NewRequest(\(literal(command.method)), \(literal(command.url)), \(command.body.isEmpty ? "nil" : "strings.NewReader(\(literal(command.body)))"))
        \(goHeaders(command))
        resp, err := http.DefaultClient.Do(req)
        """
    }

    public static func node(_ command: Command) -> String {
        """
        import fetch from "node-fetch";
        const response = await fetch(\(literal(command.url)), {
          method: \(literal(command.method)),
          headers: {\(jsHeaders(command))},
          \(command.body.isEmpty ? "" : "body: \(literal(command.body)),")
          redirect: \(literal(command.follow ? "follow" : "manual"))
        });
        console.log(response.status, await response.text());
        """
    }

    public static func render(_ text: String, language: String) -> ToolResult {
        switch parse(text) {
        case let .failure(issue):
            return .failure(issue)
        case let .success(command):
            let code: String
            switch language {
            case "python": code = python(command)
            case "javascript": code = javascript(command)
            case "go": code = goCode(command)
            case "node": code = node(command)
            default: code = swiftCode(command)
            }
            var notes = ""
            if command.insecure { notes += "\n// curl -k disables TLS verification. The snippet keeps the default secure session.\n" }
            if !command.user.isEmpty && language == "swift" {
                notes += "\n// Basic auth user was \(command.user). Add an Authorization header before sending.\n"
            }
            return .success(code + notes)
        }
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        let source = "curl -X POST https://example.com/api -H 'Content-Type: application/json' -d '{\"a\":1}'"
        let parsed = parse(source)
        if case let .success(command) = parsed {
            expect("curl method", command.method == "POST" && command.url == "https://example.com/api" && command.body == "{\"a\":1}")
        } else {
            expect("curl method", false)
        }
        let swift = render(source, language: "swift")
        expect("curl swift", swift.output.contains("URLSession") && swift.output.contains("POST"))
        expect("curl python", render(source, language: "python").output.contains("requests.post"))
        expect("curl js", render(source, language: "javascript").output.contains("fetch("))
        expect("curl go", render(source, language: "go").output.contains("http.NewRequest"))
        expect("curl node", render(source, language: "node").output.contains("node-fetch"))
        expect("curl empty", render("  ", language: "swift").issue != nil)
        expect("curl no url", render("curl -X GET", language: "swift").issue != nil)
    }

    private static func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var quote: Character?
        var escaped = false
        for character in text {
            if escaped {
                current.append(character)
                escaped = false
                continue
            }
            if character == "\\" && quote != "'" {
                escaped = true
                continue
            }
            if let active = quote, character == active {
                tokens.append(current)
                current = ""
                quote = nil
                continue
            }
            if quote == nil && (character == "\"" || character == "'") {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                quote = character
                continue
            }
            if quote == nil && character.isWhitespace {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                continue
            }
            current.append(character)
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    private static func literal(_ text: String) -> String {
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }

    private static func splitHeader(_ header: String) -> (String, String) {
        if let colon = header.firstIndex(of: ":") {
            let name = header[..<colon].trimmingCharacters(in: .whitespaces)
            let value = header[header.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            return (String(name), String(value))
        }
        return (header, "")
    }

    private enum HeaderStyle { case swift }

    private static func headerLines(_ command: Command, style: HeaderStyle) -> String {
        command.headers.map { header in
            let pair = splitHeader(header)
            return "request.setValue(\(literal(pair.1)), forHTTPHeaderField: \(literal(pair.0)))"
        }.joined(separator: "\n")
    }

    private static func jsHeaders(_ command: Command) -> String {
        command.headers.map { header in
            let pair = splitHeader(header)
            return "\(literal(pair.0)): \(literal(pair.1))"
        }.joined(separator: ", ")
    }

    private static func goHeaders(_ command: Command) -> String {
        command.headers.map { header in
            let pair = splitHeader(header)
            return "req.Header.Set(\(literal(pair.0)), \(literal(pair.1)))"
        }.joined(separator: "\n")
    }

    private static func pythonAuth(_ user: String) -> String {
        let parts = user.split(separator: ":", maxSplits: 1).map(String.init)
        let name = parts.first ?? ""
        let secret = parts.count > 1 ? parts[1] : ""
        return "(\(literal(name)), \(literal(secret)))"
    }
}
