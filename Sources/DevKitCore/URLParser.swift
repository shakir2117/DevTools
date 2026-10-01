import Foundation

public struct ParsedURL: Equatable, Sendable {
    public var scheme: String
    public var user: String
    public var password: String
    public var host: String
    public var port: String
    public var path: String
    public var query: [(name: String, value: String)]
    public var fragment: String

    public static func == (lhs: ParsedURL, rhs: ParsedURL) -> Bool {
        lhs.scheme == rhs.scheme && lhs.user == rhs.user && lhs.password == rhs.password
            && lhs.host == rhs.host && lhs.port == rhs.port && lhs.path == rhs.path
            && lhs.fragment == rhs.fragment
            && lhs.query.map { "\($0.name)=\($0.value)" } == rhs.query.map { "\($0.name)=\($0.value)" }
    }

    public init(scheme: String = "", user: String = "", password: String = "", host: String = "", port: String = "", path: String = "", query: [(name: String, value: String)] = [], fragment: String = "") {
        self.scheme = scheme
        self.user = user
        self.password = password
        self.host = host
        self.port = port
        self.path = path
        self.query = query
        self.fragment = fragment
    }

    public static func parse(_ text: String) -> Result<ParsedURL, ToolIssue> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .failure(ToolIssue(message: "Enter a URL.")) }
        if trimmed.count > 100_000 { return .failure(ToolIssue(message: "That URL is too long.")) }
        guard let components = URLComponents(string: trimmed) else {
            return .failure(ToolIssue(message: "Could not parse that URL."))
        }
        let parsed = ParsedURL(
            scheme: components.scheme ?? "",
            user: components.user ?? "",
            password: components.password ?? "",
            host: components.host ?? "",
            port: components.port.map(String.init) ?? "",
            path: components.path,
            query: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") },
            fragment: components.fragment ?? ""
        )
        return .success(parsed)
    }

    public func render() -> String {
        var components = URLComponents()
        components.scheme = scheme.isEmpty ? nil : scheme
        components.user = user.isEmpty ? nil : user
        components.password = password.isEmpty ? nil : password
        components.host = host.isEmpty ? nil : host
        if let portNumber = Int(port), !port.isEmpty { components.port = portNumber }
        components.path = path
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.name, value: $0.value) }
        }
        components.fragment = fragment.isEmpty ? nil : fragment
        return components.string ?? ""
    }
}

public enum URLParserChecks {
    public static func runChecks(_ expect: (String, Bool) -> Void) {
        let parsed = ParsedURL.parse("https://ada:secret@example.com:8443/a/b?x=1&y=hello#top")
        guard case let .success(url) = parsed else {
            expect("url parse", false)
            return
        }
        expect("url parts", url.scheme == "https" && url.user == "ada" && url.password == "secret" && url.host == "example.com" && url.port == "8443" && url.path == "/a/b" && url.fragment == "top")
        expect("url query", url.query.map(\.name) == ["x", "y"] && url.query[1].value == "hello")
        let rebuilt = ParsedURL.parse(url.render())
        if case let .success(again) = rebuilt {
            expect("url roundtrip", again == url)
        } else {
            expect("url roundtrip", false)
        }
        expect("url empty", ParsedURL.parse(" ").isFailure)
        expect("url bad", ParsedURL.parse("http://[") .isFailure)
    }
}

private extension Result where Failure == ToolIssue {
    var isFailure: Bool {
        if case .failure = self { return true }
        return false
    }
}
