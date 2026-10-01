import Foundation

public enum JSONPath {
    public static func query(_ path: String, json: String) -> ToolResult {
        if json.count > 8_000_000 { return .failure("JSON is larger than 8 MB.") }
        if let issue = InputChecks.issue(for: json, emptyPrompt: "Enter JSON to query.") {
            return .failure(issue)
        }
        let expression = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if expression.isEmpty { return .failure("Enter a path. Examples: $.name, $.items[0], $.items[*].id, $.items[?(@.ok == true)]") }
        guard let data = json.data(using: .utf8) else { return .failure("Could not read the JSON.") }
        let root: Any
        do {
            root = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            let formatted = JSONFormatter.format(json, mode: .validate, indent: .two, sortKeys: false)
            return .failure(formatted.issue ?? ToolIssue(message: "Invalid JSON."))
        }
        do {
            let tokens = try tokenize(expression)
            let matches = try evaluate(tokens, values: [root])
            let data = try JSONSerialization.data(withJSONObject: matches, options: [.prettyPrinted, .fragmentsAllowed, .sortedKeys])
            return .success(String(data: data, encoding: .utf8) ?? "")
        } catch let issue as ToolIssue {
            return .failure(issue)
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        let json = #"{"user":{"name":"Ada"},"items":[{"id":1,"ok":true},{"id":2,"ok":false}]}"#
        expect("path dot", query("$.user.name", json: json).output.contains("Ada"))
        expect("path index", query("$.items[0].id", json: json).output.contains("1"))
        expect("path wild", query("$.items[*].id", json: json).output.contains("1") && query("$.items[*].id", json: json).output.contains("2"))
        expect("path filter", query("$.items[?(@.ok == true)].id", json: json).output.contains("1") && !query("$.items[?(@.ok == true)].id", json: json).output.contains("2"))
        expect("path empty", query("", json: "{}").issue != nil)
        expect("path bad json", query("$.a", json: "{").issue != nil)
        expect("path bad", query("$.[", json: "{}").issue != nil)
    }

    private enum Token {
        case root, name(String), index(Int), wildcard, filter(String, String)
    }

    private static func tokenize(_ path: String) throws -> [Token] {
        var tokens: [Token] = []
        var index = path.startIndex
        func peek() -> Character? { index < path.endIndex ? path[index] : nil }
        func bump() -> Character? {
            guard index < path.endIndex else { return nil }
            let character = path[index]
            index = path.index(after: index)
            return character
        }
        if peek() == "$" { _ = bump(); tokens.append(.root) }
        while index < path.endIndex {
            if peek() == "." {
                _ = bump()
                if peek() == "*" {
                    _ = bump()
                    tokens.append(.wildcard)
                    continue
                }
                var name = ""
                while let character = peek(), character != "." && character != "[" {
                    guard let next = bump() else { break }
                    if next != character { name.append(next) } else { name.append(character) }
                }
                if name.isEmpty { throw ToolIssue(message: "Expected a name after '.'.") }
                tokens.append(.name(name))
            } else if peek() == "[" {
                _ = bump()
                if peek() == "*" {
                    _ = bump()
                    guard bump() == "]" else { throw ToolIssue(message: "Expected ']'.") }
                    tokens.append(.wildcard)
                    continue
                }
                if peek() == "?" {
                    guard path[index...].hasPrefix("?(@.") else { throw ToolIssue(message: "Filters look like [?(@.field == value)].") }
                    index = path.index(index, offsetBy: 4)
                    var field = ""
                    while let character = peek(), character != " " && character != "=" { field.append(bump()!) }
                    while peek() == " " || peek() == "=" { _ = bump() }
                    var raw = ""
                    if peek() == "\"" {
                        _ = bump()
                        while let character = peek(), character != "\"" { raw.append(bump()!) }
                        _ = bump()
                    } else {
                        while let character = peek(), character != ")" && character != "]" { raw.append(bump()!) }
                    }
                    guard bump() == ")" , bump() == "]" else { throw ToolIssue(message: "Expected ')].' after the filter.") }
                    tokens.append(.filter(field, raw.trimmingCharacters(in: .whitespaces)))
                    continue
                }
                var digits = ""
                while let character = peek(), character.isNumber { digits.append(bump()!) }
                guard let number = Int(digits), bump() == "]" else { throw ToolIssue(message: "Expected an index.") }
                tokens.append(.index(number))
            } else {
                throw ToolIssue(message: "Unexpected character in the path.")
            }
        }
        return tokens
    }

    private static func evaluate(_ tokens: [Token], values: [Any]) throws -> [Any] {
        var current = values
        for token in tokens {
            switch token {
            case .root:
                continue
            case let .name(name):
                current = current.flatMap { value -> [Any] in
                    guard let object = value as? [String: Any], let child = object[name] else { return [] }
                    return [child]
                }
            case let .index(index):
                current = current.flatMap { value -> [Any] in
                    guard let array = value as? [Any], array.indices.contains(index) else { return [] }
                    return [array[index]]
                }
            case .wildcard:
                current = current.flatMap { value -> [Any] in
                    if let array = value as? [Any] { return array }
                    if let object = value as? [String: Any] { return object.keys.sorted().compactMap { object[$0] } }
                    return []
                }
            case let .filter(field, expected):
                current = current.flatMap { value -> [Any] in
                    guard let array = value as? [Any] else { return [] }
                    return array.filter { item in
                        guard let object = item as? [String: Any] else { return false }
                        return matches(object[field], expected: expected)
                    }
                }
            }
        }
        return current
    }

    private static func matches(_ value: Any?, expected: String) -> Bool {
        if expected == "true" { return (value as? NSNumber).map { CFGetTypeID($0) == CFBooleanGetTypeID() && $0.boolValue } ?? false }
        if expected == "false" { return (value as? NSNumber).map { CFGetTypeID($0) == CFBooleanGetTypeID() && !$0.boolValue } ?? false }
        if expected == "null" { return value is NSNull || value == nil }
        if let number = Double(expected), let actual = value as? NSNumber, CFGetTypeID(actual) != CFBooleanGetTypeID() {
            return actual.doubleValue == number
        }
        if let string = value as? String { return string == expected }
        return false
    }
}
