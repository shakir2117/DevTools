import Foundation

public enum XMLToJSON {
    public static func convert(_ text: String) -> ToolResult {
        if text.count > 8_000_000 { return .failure("XML is larger than 8 MB.") }
        if let issue = InputChecks.issue(for: text, emptyPrompt: "Enter XML to convert.") {
            return .failure(issue)
        }
        do {
            let document = try XMLDocument(xmlString: text, options: [.nodeLoadExternalEntitiesNever])
            guard let root = document.rootElement(), let name = root.name else {
                return .failure("XML document has no root element.")
            }
            let object = [name: value(for: root)]
            let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
            guard let output = String(data: data, encoding: .utf8) else { return .failure("Could not encode JSON.") }
            return .success(output)
        } catch {
            let ns = error as NSError
            return .failure(ToolIssue(
                message: ns.localizedDescription,
                line: ns.userInfo["NSXMLParserErrorLineNumber"] as? Int,
                column: ns.userInfo["NSXMLParserErrorColumn"] as? Int
            ))
        }
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        let xml = "<book id=\"1\"><title>Hi</title><tag>a</tag><tag>b</tag></book>"
        let json = convert(xml)
        expect("xml json attrs", json.issue == nil && json.output.contains("\"@id\"") && json.output.contains("\"1\""))
        expect("xml json text", json.output.contains("\"title\"") && json.output.contains("Hi"))
        expect("xml json array", json.output.contains("\"tag\"") && json.output.contains("[") && json.output.contains("\"a\"") && json.output.contains("\"b\""))
        let textOnly = convert("<name>Ada</name>")
        expect("xml json plain text", textOnly.output.contains("\"name\"") && textOnly.output.contains("Ada") && !textOnly.output.contains("#text"))
        expect("xml json empty", convert(" ").issue != nil)
        expect("xml json bad", convert("<book>").issue != nil)
    }

    private static func value(for element: XMLElement) -> Any {
        var attributes: [String: String] = [:]
        for attribute in element.attributes ?? [] {
            if let name = attribute.name {
                attributes["@\(name)"] = attribute.stringValue ?? ""
            }
        }
        var children: [String: [Any]] = [:]
        var texts: [String] = []
        for child in element.children ?? [] {
            if child.kind == .text {
                let text = (child.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { texts.append(text) }
            } else if let nested = child as? XMLElement, let name = nested.name {
                children[name, default: []].append(value(for: nested))
            }
        }
        if attributes.isEmpty && children.isEmpty {
            return texts.joined(separator: " ")
        }
        var object: [String: Any] = [:]
        for (key, value) in attributes { object[key] = value }
        for (key, values) in children {
            object[key] = values.count == 1 ? values[0] : values
        }
        if !texts.isEmpty {
            object["#text"] = texts.joined(separator: " ")
        }
        return object
    }
}
