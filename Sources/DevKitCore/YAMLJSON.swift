import Foundation
import Yams

public enum YAMLFormatter {
    public enum Mode: String, Sendable {
        case prettify, validate
    }

    public static func format(_ text: String, mode: Mode) -> ToolResult {
        if text.count > 8_000_000 { return .failure("YAML is larger than 8 MB.") }
        if let issue = InputChecks.issue(for: text, emptyPrompt: "Enter YAML to format.") {
            return .failure(issue)
        }
        do {
            guard let node = try compose(yaml: text) else {
                return .failure("YAML document is empty.")
            }
            switch mode {
            case .validate:
                return .success("Valid YAML.")
            case .prettify:
                let output = try serialize(node: node, indent: 2, width: -1, allowUnicode: true)
                return .success(output.trimmingCharacters(in: .newlines) + "\n")
            }
        } catch {
            return .failure(yamlIssue(error))
        }
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        let pretty = format("a: 1\nb: [true, null]", mode: .prettify)
        expect("yaml pretty", pretty.issue == nil && pretty.output.contains("a:"))
        expect("yaml validate", format("ok: true", mode: .validate).output.contains("Valid YAML"))
        expect("yaml bad", format("a: [\n", mode: .prettify).issue != nil)
        expect("yaml empty", format("  ", mode: .validate).issue != nil)
    }
}

public enum YAMLJSON {
    public static func jsonToYAML(_ text: String) -> ToolResult {
        if text.count > 8_000_000 { return .failure("JSON is larger than 8 MB.") }
        if let issue = InputChecks.issue(for: text, emptyPrompt: "Enter JSON to convert.") {
            return .failure(issue)
        }
        guard let data = text.data(using: .utf8) else { return .failure("Could not read the JSON.") }
        do {
            let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            let yaml = try serialize(node: node(from: object), indent: 2, width: -1, allowUnicode: true)
            return .success(yaml.trimmingCharacters(in: .newlines) + "\n")
        } catch let error as YamlError {
            return .failure(yamlIssue(error))
        } catch {
            let formatted = JSONFormatter.format(text, mode: .validate, indent: .two, sortKeys: false)
            return .failure(formatted.issue ?? ToolIssue(message: "Invalid JSON."))
        }
    }

    public static func yamlToJSON(_ text: String) -> ToolResult {
        if text.count > 8_000_000 { return .failure("YAML is larger than 8 MB.") }
        if let issue = InputChecks.issue(for: text, emptyPrompt: "Enter YAML to convert.") {
            return .failure(issue)
        }
        do {
            guard let node = try compose(yaml: text) else { return .failure("YAML document is empty.") }
            let object = jsonObject(from: node)
            let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed])
            guard let output = String(data: data, encoding: .utf8) else { return .failure("Could not encode JSON.") }
            return .success(output)
        } catch {
            return .failure(yamlIssue(error))
        }
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        let yaml = jsonToYAML(#"{"b":1,"a":true,"c":null}"#)
        expect("json to yaml", yaml.issue == nil && yaml.output.contains("a: true") && yaml.output.contains("b: 1"))
        let json = yamlToJSON("a: 1\nb: yes\n")
        expect("yaml to json", json.issue == nil && json.output.contains("\"a\"") && json.output.contains("1"))
        let round = yamlToJSON(jsonToYAML(#"{"name":"Ada","n":2}"#).output)
        let back = jsonToYAML(round.output)
        expect("json yaml roundtrip", round.issue == nil && back.output.contains("name: Ada") && back.output.contains("n: 2"))
        expect("yaml json empty", jsonToYAML(" ").issue != nil)
        expect("yaml json bad", yamlToJSON("[\n").issue != nil)
    }

    private static func node(from value: Any) -> Node {
        if value is NSNull { return Node("null", Tag(.null)) }
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return Node(number.boolValue ? "true" : "false", Tag(.bool))
            }
            let double = number.doubleValue
            if double.rounded() == double, abs(double) < 9_007_199_254_740_992 {
                return Node(String(format: "%.0f", double), Tag(.int))
            }
            return Node(String(double), Tag(.float))
        }
        if let string = value as? String { return Node(string, Tag(.str)) }
        if let array = value as? [Any] { return Node(array.map(node(from:))) }
        if let object = value as? [String: Any] {
            let pairs = object.keys.sorted().map { (Node($0, Tag(.str)), node(from: object[$0] as Any)) }
            return Node(pairs)
        }
        return Node(String(describing: value), Tag(.str))
    }

    private static func jsonObject(from node: Node) -> Any {
        switch node {
        case .scalar:
            if node.null != nil { return NSNull() }
            if let bool = node.bool { return bool }
            if let int = node.int { return int }
            if let double = node.float { return double }
            return node.string ?? ""
        case let .sequence(sequence):
            return sequence.map { jsonObject(from: $0) }
        case let .mapping(mapping):
            var object: [String: Any] = [:]
            for pair in mapping {
                object[pair.key.string ?? String(describing: pair.key)] = jsonObject(from: pair.value)
            }
            return object
        case .alias:
            return jsonObject(from: Node(node.any as? String ?? ""))
        }
    }
}

func yamlIssue(_ error: Error) -> ToolIssue {
    guard let yaml = error as? YamlError else {
        let ns = error as NSError
        return ToolIssue(message: ns.localizedDescription.isEmpty ? "Invalid YAML." : ns.localizedDescription)
    }
    switch yaml {
    case let .parser(_, problem, mark, _),
         let .scanner(_, problem, mark, _),
         let .composer(_, problem, mark, _):
        return ToolIssue(message: problem, line: mark.line, column: mark.column)
    case let .reader(problem, _, _, _):
        return ToolIssue(message: problem)
    default:
        return ToolIssue(message: String(describing: yaml))
    }
}
