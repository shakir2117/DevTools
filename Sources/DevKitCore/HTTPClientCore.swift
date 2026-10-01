import Foundation

public struct HTTPField: Codable, Equatable, Sendable {
    public var name: String
    public var value: String
    public init(name: String = "", value: String = "") {
        self.name = name
        self.value = value
    }
}

public struct HTTPSpec: Equatable, Sendable {
    public var method: String
    public var url: String
    public var query: [HTTPField]
    public var headers: [HTTPField]
    public var bodyKind: String
    public var body: String
    public var form: [HTTPField]
    public var auth: String
    public var authValue: String
    public var authSecret: String
    public var followRedirects: Bool
    public var timeout: Double
    public var environment: [String: String]

    public init(method: String = "GET", url: String = "", query: [HTTPField] = [], headers: [HTTPField] = [], bodyKind: String = "none", body: String = "", form: [HTTPField] = [], auth: String = "none", authValue: String = "", authSecret: String = "", followRedirects: Bool = true, timeout: Double = 30, environment: [String: String] = [:]) {
        self.method = method
        self.url = url
        self.query = query
        self.headers = headers
        self.bodyKind = bodyKind
        self.body = body
        self.form = form
        self.auth = auth
        self.authValue = authValue
        self.authSecret = authSecret
        self.followRedirects = followRedirects
        self.timeout = timeout
        self.environment = environment
    }
}

public struct HTTPReport: Equatable, Sendable {
    public var summary: String
    public var body: String
    public var statusLine: String
    public var responseHeaders: String

    public init(summary: String, body: String, statusLine: String = "", responseHeaders: String = "") {
        self.summary = summary
        self.body = body
        self.statusLine = statusLine
        self.responseHeaders = responseHeaders
    }
}

public enum HTTPClientCore {
    public static func substitute(_ text: String, environment: [String: String]) -> String {
        var result = text
        for (key, value) in environment {
            result = result.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        return result
    }

    public static func build(_ spec: HTTPSpec) throws -> URLRequest {
        let expanded = substitute(spec.url, environment: spec.environment)
        guard var components = URLComponents(string: expanded) else {
            throw ToolIssue(message: "Enter a valid URL.")
        }
        if components.scheme == nil {
            guard let upgraded = URLComponents(string: "https://\(expanded)"),
                  let host = upgraded.host, !host.isEmpty else {
                throw ToolIssue(message: "Enter a valid URL.")
            }
            components = upgraded
        }
        let extra = spec.query.filter { !$0.name.isEmpty }.map {
            URLQueryItem(name: substitute($0.name, environment: spec.environment), value: substitute($0.value, environment: spec.environment))
        }
        if !extra.isEmpty {
            components.queryItems = (components.queryItems ?? []) + extra
        }
        let scheme = components.scheme?.lowercased()
        guard scheme == "http" || scheme == "https" else {
            throw ToolIssue(message: "Only http and https URLs are allowed.")
        }
        guard let url = components.url, let host = url.host, !host.isEmpty else {
            throw ToolIssue(message: "Enter a valid URL.")
        }
        let method = spec.method.isEmpty ? "GET" : spec.method.uppercased()
        let allowedMethods = ["GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS"]
        guard allowedMethods.contains(method) else {
            throw ToolIssue(message: "That HTTP method is not allowed.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = max(1, min(spec.timeout, 300))
        for header in spec.headers where !header.name.isEmpty {
            let name = substitute(header.name, environment: spec.environment)
            let value = substitute(header.value, environment: spec.environment)
            guard !name.isEmpty, headerField(name), headerField(value), !name.contains(":") else {
                throw ToolIssue(message: "A header contains a line break or colon.")
            }
            request.setValue(value, forHTTPHeaderField: name)
        }
        switch spec.auth {
        case "basic":
            let token = Data("\(spec.authValue):\(spec.authSecret)".utf8).base64EncodedString()
            request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
        case "bearer":
            request.setValue("Bearer \(substitute(spec.authValue, environment: spec.environment))", forHTTPHeaderField: "Authorization")
        case "apikey":
            let name = spec.authSecret.isEmpty ? "X-API-Key" : spec.authSecret
            request.setValue(substitute(spec.authValue, environment: spec.environment), forHTTPHeaderField: name)
        default:
            break
        }
        switch spec.bodyKind {
        case "raw":
            request.httpBody = Data(substitute(spec.body, environment: spec.environment).utf8)
        case "form":
            let encoded = spec.form.filter { !$0.name.isEmpty }.map { field -> String in
                let name = formEscape(substitute(field.name, environment: spec.environment))
                let value = formEscape(substitute(field.value, environment: spec.environment))
                return "\(name)=\(value)"
            }.joined(separator: "&")
            request.httpBody = Data(encoded.utf8)
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            }
        case "multipart":
            let boundary = "DevKitBoundary\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
            var body = Data()
            for field in spec.form where !field.name.isEmpty {
                let name = substitute(field.name, environment: spec.environment)
                guard headerField(name), !name.contains("\"") else {
                    throw ToolIssue(message: "A form field name contains a line break or quote.")
                }
                body.append(Data("--\(boundary)\r\n".utf8))
                body.append(Data("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".utf8))
                body.append(Data(substitute(field.value, environment: spec.environment).utf8))
                body.append(Data("\r\n".utf8))
            }
            body.append(Data("--\(boundary)--\r\n".utf8))
            request.httpBody = body
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        default:
            break
        }
        return request
    }

    public static func send(_ spec: HTTPSpec) async -> HTTPReport {
        let request: URLRequest
        do { request = try build(spec) } catch let issue as ToolIssue {
            return HTTPReport(summary: issue.message, body: "")
        } catch {
            return HTTPReport(summary: error.localizedDescription, body: "")
        }
        let delegate = RedirectGate(follow: spec.followRedirects)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = max(1, min(spec.timeout, 300))
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        let started = Date()
        do {
            let (data, response) = try await session.data(for: request)
            let elapsed = Date().timeIntervalSince(started)
            let http = response as? HTTPURLResponse
            let status = http?.statusCode ?? 0
            let reason = HTTPStatus.all.first { $0.code == status }?.reason ?? ""
            let headerText = (http?.allHeaderFields ?? [:]).map { "\($0.key): \($0.value)" }.sorted().joined(separator: "\n")
            let cookies: String
            if let url = request.url {
                cookies = session.configuration.httpCookieStorage?.cookies(for: url)?.map { "\($0.name)=\($0.value)" }.joined(separator: "\n") ?? ""
            } else {
                cookies = ""
            }
            let body = String(data: data, encoding: .utf8) ?? "Binary response, \(data.count) bytes."
            let statusLine = """
            \(status) \(reason)
            Time: \(String(format: "%.0f", elapsed * 1000)) ms
            Size: \(data.count) bytes
            Final URL: \(http?.url?.absoluteString ?? request.url?.absoluteString ?? "")
            """
            let summary = """
            \(statusLine)

            Headers:
            \(headerText)

            Cookies:
            \(cookies.isEmpty ? "(none)" : cookies)
            """
            return HTTPReport(summary: summary, body: body, statusLine: statusLine, responseHeaders: headerText)
        } catch {
            return HTTPReport(summary: error.localizedDescription, body: "")
        }
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        var spec = HTTPSpec(method: "POST", url: "https://{{host}}/v1", query: [HTTPField(name: "q", value: "1")])
        spec.environment = ["host": "example.com"]
        spec.auth = "basic"
        spec.authValue = "ada"
        spec.authSecret = "secret"
        spec.bodyKind = "raw"
        spec.body = "{\"ok\":true}"
        do {
            let request = try build(spec)
            expect("http url", request.url?.absoluteString == "https://example.com/v1?q=1")
            expect("http method", request.httpMethod == "POST")
            expect("http basic", request.value(forHTTPHeaderField: "Authorization")?.hasPrefix("Basic ") == true)
            expect("http body", String(data: request.httpBody ?? Data(), encoding: .utf8) == "{\"ok\":true}")
        } catch {
            expect("http url", false)
            expect("http method", false)
            expect("http basic", false)
            expect("http body", false)
        }
        expect("http bad url", (try? build(HTTPSpec(url: "://"))) == nil)
        expect("http file blocked", (try? build(HTTPSpec(url: "file:///etc/passwd"))) == nil)
        expect("http header break", (try? build(HTTPSpec(url: "https://example.com", headers: [HTTPField(name: "X\nY", value: "1")]))) == nil)
        expect("http env", substitute("hi {{name}}", environment: ["name": "Ada"]) == "hi Ada")
    }

    private static func headerField(_ text: String) -> Bool {
        !text.contains("\r") && !text.contains("\n") && !text.contains("\0")
    }

    private static func formEscape(_ text: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+")
        return text.addingPercentEncoding(withAllowedCharacters: allowed) ?? text
    }
}

private final class RedirectGate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    let follow: Bool
    init(follow: Bool) { self.follow = follow }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        let scheme = request.url?.scheme?.lowercased()
        guard follow, scheme == "https" || scheme == "http" else {
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }
}
