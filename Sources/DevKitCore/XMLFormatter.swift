import Foundation

public enum XMLFormatter {
    public enum Mode: String, Sendable {
        case prettify, minify, validate
    }

    public static func format(_ text: String, mode: Mode) -> ToolResult {
        if text.count > 8_000_000 { return .failure("XML is larger than 8 MB.") }
        if let issue = InputChecks.issue(for: text, emptyPrompt: "Enter XML to format.") {
            return .failure(issue)
        }
        do {
            let document = try XMLDocument(xmlString: text, options: [.nodeLoadExternalEntitiesNever])
            guard let root = document.rootElement() else {
                return .failure("XML document has no root element.")
            }
            switch mode {
            case .validate:
                return .success("Valid XML (root <\(root.name ?? "element")>).")
            case .prettify:
                return .success(declaration(for: text) + emit(root, pretty: true, level: 0))
            case .minify:
                return .success(declaration(for: text) + emit(root, pretty: false, level: 0))
            }
        } catch {
            return .failure(issue(for: error))
        }
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        let pretty = format("<root><a>1</a><b/></root>", mode: .prettify)
        expect("xml pretty", pretty.issue == nil && pretty.output.contains("<a>1</a>") && pretty.output.contains("\n"))
        let mini = format("<root>\n  <a>1</a>\n</root>", mode: .minify)
        expect("xml minify", mini.issue == nil && !mini.output.contains("\n  "))
        expect("xml validate", format("<root/>", mode: .validate).output.contains("Valid XML"))
        let bad = format("<root>", mode: .prettify)
        expect("xml malformed", bad.issue != nil)
        expect("xml empty", format("  ", mode: .minify).issue != nil)
        expect("xml binary", format(String(repeating: "\u{0}", count: 4), mode: .validate).issue != nil)
    }

    private static func declaration(for text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("<?xml") {
            return "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
        }
        return ""
    }

    private static func emit(_ node: XMLNode, pretty: Bool, level: Int) -> String {
        if node.kind == .comment {
            let body = node.stringValue ?? ""
            return indent(pretty, level) + "<!--\(body)-->"
        }
        guard let element = node as? XMLElement else {
            return node.stringValue ?? ""
        }
        let name = element.name ?? "unnamed"
        let attributes = (element.attributes ?? []).compactMap { attribute -> String? in
            guard let attrName = attribute.name else { return nil }
            return " \(attrName)=\"\(escape(attribute.stringValue ?? "", attribute: true))\""
        }.joined()
        let children = (element.children ?? []).filter { child in
            if child.kind == .text {
                return !(child.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            return child.kind == .element || child.kind == .comment
        }
        let pad = indent(pretty, level)
        let prefix = declarationPrefix(pretty: pretty, level: level)
        if children.isEmpty {
            return "\(prefix)\(pad)<\(name)\(attributes)/>"
        }
        if children.count == 1, children[0].kind == .text, let text = children[0].stringValue {
            return "\(prefix)\(pad)<\(name)\(attributes)>\(escape(text, attribute: false))</\(name)>"
        }
        let inner = children.map { emit($0, pretty: pretty, level: level + 1) }.joined(separator: pretty ? "\n" : "")
        if pretty {
            return "\(prefix)\(pad)<\(name)\(attributes)>\n\(inner)\n\(pad)</\(name)>"
        }
        return "<\(name)\(attributes)>\(inner)</\(name)>"
    }

    private static func declarationPrefix(pretty: Bool, level: Int) -> String { "" }

    private static func indent(_ pretty: Bool, _ level: Int) -> String {
        pretty ? String(repeating: "  ", count: level) : ""
    }

    private static func escape(_ text: String, attribute: Bool) -> String {
        var result = text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        if attribute {
            result = result.replacingOccurrences(of: "\"", with: "&quot;")
        }
        return result
    }

    private static func issue(for error: Error) -> ToolIssue {
        let ns = error as NSError
        let line = ns.userInfo["NSXMLParserErrorLineNumber"] as? Int
        let column = ns.userInfo["NSXMLParserErrorColumn"] as? Int
        let message = ns.localizedDescription.isEmpty ? "Invalid XML." : ns.localizedDescription
        return ToolIssue(message: message, line: line, column: column)
    }
}
