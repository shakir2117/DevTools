import Foundation

public enum DotEnv {
    public enum Format: String {
        case json
        case dotenv
        case shell
    }

    public static func convert(_ text: String, format: Format) -> ToolResult {
        if text.utf8.count > 1_000_000 { return .failure("Input is larger than 1 MB.") }
        if text.utf8.contains(0) { return .failure("Input looks like binary data.") }
        switch parse(text) {
        case let .failure(issue):
            return .failure(issue)
        case let .success(pairs):
            switch format {
            case .json:
                let object = Dictionary(uniqueKeysWithValues: pairs.map { ($0.0, $0.1) })
                guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
                      let json = String(data: data, encoding: .utf8) else {
                    return .failure("Could not write JSON.")
                }
                return .success(json)
            case .dotenv:
                return .success(pairs.map { "\($0.0)=\(quote($0.1))" }.joined(separator: "\n"))
            case .shell:
                return .success(pairs.map { "export \($0.0)=\(quote($0.1))" }.joined(separator: "\n"))
            }
        }
    }

    public static func parse(_ text: String) -> Result<[(String, String)], ToolIssue> {
        var pairs: [(String, String)] = []
        for raw in text.split(whereSeparator: \.isNewline) {
            var line = String(raw).trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            if line.hasPrefix("export ") { line.removeFirst(7) }
            guard let mark = line.firstIndex(of: "=") else {
                return .failure(ToolIssue(message: "Each line needs KEY=value."))
            }
            let key = String(line[..<mark]).trimmingCharacters(in: .whitespaces)
            var value = String(line[line.index(after: mark)...])
            if key.isEmpty || key.contains(" ") || key.contains("\n") || key.hasPrefix("-") {
                return .failure(ToolIssue(message: "\"\(key)\" is not a valid name."))
            }
            value = unquote(value.trimmingCharacters(in: .whitespaces))
            pairs.append((key, value))
        }
        return .success(pairs)
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        let source = "# comment\nexport FOO=\"a b\"\nBAR=c\n"
        let json = convert(source, format: .json)
        expect("env json", json.output.contains("\"FOO\" : \"a b\"") || json.output.contains("\"FOO\": \"a b\""))
        expect("env bar", json.output.contains("\"BAR\""))
        expect("env bad", convert("-BAD=1", format: .json).issue != nil)
    }

    private static func unquote(_ value: String) -> String {
        guard value.count >= 2 else { return value }
        let first = value.first
        let last = value.last
        guard (first == "\"" && last == "\"") || (first == "'" && last == "'") else { return value }
        let body = String(value.dropFirst().dropLast())
        if first == "'" { return body }
        var result = ""
        var escaped = false
        for character in body {
            if escaped {
                switch character {
                case "n": result.append("\n")
                case "t": result.append("\t")
                default: result.append(character)
                }
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else {
                result.append(character)
            }
        }
        return result
    }

    private static func quote(_ value: String) -> String {
        if value.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" || $0 == "." || $0 == "/" }) {
            return value
        }
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }
}
