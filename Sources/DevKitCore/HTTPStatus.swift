import Foundation

public enum HTTPStatus {
    public struct Entry: Identifiable, Sendable {
        public var code: Int
        public var reason: String
        public var summary: String
        public var id: Int { code }
    }

    public static let all: [Entry] = [
        Entry(code: 100, reason: "Continue", summary: "The client should continue the request."),
        Entry(code: 101, reason: "Switching Protocols", summary: "The server is switching protocols."),
        Entry(code: 102, reason: "Processing", summary: "WebDAV: the server is still working."),
        Entry(code: 103, reason: "Early Hints", summary: "Hints to preload resources before the final response."),
        Entry(code: 200, reason: "OK", summary: "The request succeeded."),
        Entry(code: 201, reason: "Created", summary: "A resource was created."),
        Entry(code: 202, reason: "Accepted", summary: "Accepted for later processing."),
        Entry(code: 203, reason: "Non-Authoritative Information", summary: "Metadata came from a transforming proxy."),
        Entry(code: 204, reason: "No Content", summary: "Success with an empty body."),
        Entry(code: 205, reason: "Reset Content", summary: "The client should reset its document view."),
        Entry(code: 206, reason: "Partial Content", summary: "A range of the resource was sent."),
        Entry(code: 207, reason: "Multi-Status", summary: "WebDAV status for multiple resources."),
        Entry(code: 208, reason: "Already Reported", summary: "WebDAV: members were already enumerated."),
        Entry(code: 226, reason: "IM Used", summary: "The response is a delta encoding."),
        Entry(code: 300, reason: "Multiple Choices", summary: "More than one representation is available."),
        Entry(code: 301, reason: "Moved Permanently", summary: "The resource has a new permanent URI."),
        Entry(code: 302, reason: "Found", summary: "Temporary redirect."),
        Entry(code: 303, reason: "See Other", summary: "Fetch the result with GET."),
        Entry(code: 304, reason: "Not Modified", summary: "Cached representation is still fresh."),
        Entry(code: 305, reason: "Use Proxy", summary: "Deprecated proxy redirect."),
        Entry(code: 307, reason: "Temporary Redirect", summary: "Temporary redirect that keeps the method."),
        Entry(code: 308, reason: "Permanent Redirect", summary: "Permanent redirect that keeps the method."),
        Entry(code: 400, reason: "Bad Request", summary: "The server could not understand the request."),
        Entry(code: 401, reason: "Unauthorized", summary: "Authentication is required or failed."),
        Entry(code: 402, reason: "Payment Required", summary: "Reserved for future payment use."),
        Entry(code: 403, reason: "Forbidden", summary: "The server refuses the request."),
        Entry(code: 404, reason: "Not Found", summary: "The resource does not exist."),
        Entry(code: 405, reason: "Method Not Allowed", summary: "The method is not allowed for this resource."),
        Entry(code: 406, reason: "Not Acceptable", summary: "No representation matches Accept."),
        Entry(code: 407, reason: "Proxy Authentication Required", summary: "Authenticate with the proxy."),
        Entry(code: 408, reason: "Request Timeout", summary: "The server timed out waiting for the request."),
        Entry(code: 409, reason: "Conflict", summary: "The request conflicts with current state."),
        Entry(code: 410, reason: "Gone", summary: "The resource is gone permanently."),
        Entry(code: 411, reason: "Length Required", summary: "Content-Length is required."),
        Entry(code: 412, reason: "Precondition Failed", summary: "A precondition header failed."),
        Entry(code: 413, reason: "Content Too Large", summary: "The body is too large."),
        Entry(code: 414, reason: "URI Too Long", summary: "The URI is too long."),
        Entry(code: 415, reason: "Unsupported Media Type", summary: "The body media type is unsupported."),
        Entry(code: 416, reason: "Range Not Satisfiable", summary: "The requested range is outside the resource."),
        Entry(code: 417, reason: "Expectation Failed", summary: "The Expect header cannot be met."),
        Entry(code: 418, reason: "I'm a teapot", summary: "The server refuses to brew coffee."),
        Entry(code: 421, reason: "Misdirected Request", summary: "The request was sent to a server that cannot produce a response."),
        Entry(code: 422, reason: "Unprocessable Content", summary: "The body was understood but could not be processed."),
        Entry(code: 423, reason: "Locked", summary: "The resource is locked."),
        Entry(code: 424, reason: "Failed Dependency", summary: "The action failed because a previous action failed."),
        Entry(code: 425, reason: "Too Early", summary: "The server is unwilling to process a request that might be replayed."),
        Entry(code: 426, reason: "Upgrade Required", summary: "The client should switch protocols."),
        Entry(code: 428, reason: "Precondition Required", summary: "The origin requires a conditional request."),
        Entry(code: 429, reason: "Too Many Requests", summary: "The client is being rate limited."),
        Entry(code: 431, reason: "Request Header Fields Too Large", summary: "The headers are too large."),
        Entry(code: 451, reason: "Unavailable For Legal Reasons", summary: "The resource is blocked for legal reasons."),
        Entry(code: 500, reason: "Internal Server Error", summary: "The server hit an unexpected condition."),
        Entry(code: 501, reason: "Not Implemented", summary: "The server does not support the method."),
        Entry(code: 502, reason: "Bad Gateway", summary: "An upstream server returned an invalid response."),
        Entry(code: 503, reason: "Service Unavailable", summary: "The server is temporarily overloaded or down."),
        Entry(code: 504, reason: "Gateway Timeout", summary: "An upstream server timed out."),
        Entry(code: 505, reason: "HTTP Version Not Supported", summary: "The HTTP version is not supported."),
        Entry(code: 506, reason: "Variant Also Negotiates", summary: "Transparent content negotiation loop."),
        Entry(code: 507, reason: "Insufficient Storage", summary: "The server cannot store the representation."),
        Entry(code: 508, reason: "Loop Detected", summary: "The server detected an infinite loop."),
        Entry(code: 510, reason: "Not Extended", summary: "Further extensions are required."),
        Entry(code: 511, reason: "Network Authentication Required", summary: "The client must authenticate to the network."),
    ]

    public static func search(_ query: String) -> [Entry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return all }
        return all.filter {
            String($0.code).contains(trimmed)
                || $0.reason.localizedCaseInsensitiveContains(trimmed)
                || $0.summary.localizedCaseInsensitiveContains(trimmed)
        }
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        expect("status 404", search("404").first?.reason == "Not Found")
        expect("status teapot", search("teapot").first?.code == 418)
        expect("status all", all.count >= 60)
        expect("status empty query", search(" ").count == all.count)
        expect("status none", search("zzzz-not-a-code").isEmpty)
    }
}
