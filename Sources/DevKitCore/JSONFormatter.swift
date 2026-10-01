import Foundation

public enum JSONFormatter {
    public enum Mode: String, Sendable {
        case beautify, minify, validate
    }

    public enum Indent: String, Sendable {
        case two, four, tab

        public var unit: String {
            switch self {
            case .two: return "  "
            case .four: return "    "
            case .tab: return "\t"
            }
        }
    }

    public static func format(_ text: String, mode: Mode, indent: Indent, sortKeys: Bool) -> ToolResult {
        if let issue = InputChecks.issue(for: text, emptyPrompt: "Enter JSON to format.") {
            return .failure(issue)
        }
        let data = Data(text.utf8)
        do {
            let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            switch mode {
            case .validate:
                return .success("Valid JSON (\(describe(object))).")
            case .minify:
                var options: JSONSerialization.WritingOptions = [.fragmentsAllowed]
                if sortKeys { options.insert(.sortedKeys) }
                let written = try JSONSerialization.data(withJSONObject: object, options: options)
                guard let output = String(data: written, encoding: .utf8) else {
                    return .failure("Could not encode JSON.")
                }
                return .success(output)
            case .beautify:
                return .success(render(object, indent: indent.unit, level: 0, sort: sortKeys))
            }
        } catch {
            return .failure(issue(for: error, in: text))
        }
    }

    private static func issue(for error: Error, in text: String) -> ToolIssue {
        let ns = error as NSError
        let message = ns.localizedDescription.isEmpty ? "Invalid JSON." : ns.localizedDescription
        let index = ns.userInfo["NSJSONSerializationErrorIndex"] as? Int
            ?? ns.userInfo["NSDebugDescription"] as? Int
        if let index {
            let location = InputChecks.lineColumn(in: text, utf8Offset: index)
            return ToolIssue(message: message, line: location.line, column: location.column)
        }
        return ToolIssue(message: message)
    }

    private static func describe(_ value: Any) -> String {
        if value is NSNull { return "null" }
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() { return "boolean" }
            return "number"
        }
        if value is NSString { return "string" }
        if let array = value as? NSArray { return "array, \(array.count) items" }
        if let object = value as? NSDictionary { return "object, \(object.count) keys" }
        return "value"
    }

    private static func render(_ value: Any, indent: String, level: Int, sort: Bool) -> String {
        if let object = value as? NSDictionary {
            var pairs: [(String, Any)] = []
            pairs.reserveCapacity(object.count)
            for case let key as String in object.allKeys {
                if let item = object[key] {
                    pairs.append((key, item))
                }
            }
            if sort {
                pairs.sort { $0.0 < $1.0 }
            }
            if pairs.isEmpty { return "{}" }
            let pad = String(repeating: indent, count: level)
            let inner = String(repeating: indent, count: level + 1)
            var lines = ["{"]
            for (index, pair) in pairs.enumerated() {
                let key = encodeFragment(pair.0) ?? "\"\""
                let rendered = render(pair.1, indent: indent, level: level + 1, sort: sort)
                let comma = index == pairs.count - 1 ? "" : ","
                lines.append("\(inner)\(key): \(rendered)\(comma)")
            }
            lines.append("\(pad)}")
            return lines.joined(separator: "\n")
        }
        if let array = value as? NSArray {
            if array.count == 0 { return "[]" }
            let pad = String(repeating: indent, count: level)
            let inner = String(repeating: indent, count: level + 1)
            var lines = ["["]
            for index in 0..<array.count {
                let rendered = render(array[index], indent: indent, level: level + 1, sort: sort)
                let comma = index == array.count - 1 ? "" : ","
                lines.append("\(inner)\(rendered)\(comma)")
            }
            lines.append("\(pad)]")
            return lines.joined(separator: "\n")
        }
        return encodeFragment(value) ?? "null"
    }

    private static func encodeFragment(_ value: Any) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed]) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
