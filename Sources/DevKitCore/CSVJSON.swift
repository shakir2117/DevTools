import Foundation

public enum CSVJSON {
    public static func csvToJSON(_ text: String, delimiter: Character, header: Bool, infer: Bool) -> ToolResult {
        if text.count > 8_000_000 { return .failure("CSV is larger than 8 MB.") }
        if let issue = InputChecks.issue(for: text, emptyPrompt: "Enter CSV to convert.") {
            return .failure(issue)
        }
        let rows = parse(text, delimiter: delimiter)
        if rows.isEmpty || (rows.count == 1 && rows[0].allSatisfy { $0.isEmpty }) {
            return .failure("CSV has no rows.")
        }
        let object: Any
        if header {
            let keys = uniqueKeys(rows[0])
            let records: [[String: Any]] = rows.dropFirst().map { row in
                var record: [String: Any] = [:]
                for (index, key) in keys.enumerated() {
                    let field = index < row.count ? row[index] : ""
                    record[key] = infer ? inferValue(field) : field
                }
                return record
            }
            object = records
        } else {
            object = rows.map { row in row.map { infer ? inferValue($0) : $0 } }
        }
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let output = String(data: data, encoding: .utf8) else {
            return .failure("Could not encode JSON.")
        }
        return .success(output)
    }

    public static func jsonToCSV(_ text: String, delimiter: Character, header: Bool) -> ToolResult {
        if text.count > 8_000_000 { return .failure("JSON is larger than 8 MB.") }
        if let issue = InputChecks.issue(for: text, emptyPrompt: "Enter JSON to convert.") {
            return .failure(issue)
        }
        guard let data = text.data(using: .utf8) else { return .failure("Could not read the JSON.") }
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            let formatted = JSONFormatter.format(text, mode: .validate, indent: .two, sortKeys: false)
            return .failure(formatted.issue ?? ToolIssue(message: "Invalid JSON."))
        }
        let rows: [[String]]
        if let records = object as? [[String: Any]] {
            let keys = header ? Array(Set(records.flatMap(\.keys))).sorted() : Array(Set(records.flatMap(\.keys))).sorted()
            var table: [[String]] = []
            if header { table.append(keys) }
            for record in records {
                table.append(keys.map { scalarString(record[$0] ?? "") })
            }
            rows = table
        } else if let matrix = object as? [[Any]] {
            rows = matrix.map { $0.map(scalarString) }
        } else if let one = object as? [String: Any] {
            let keys = one.keys.sorted()
            rows = header ? [keys, keys.map { scalarString(one[$0] ?? "") }] : [keys.map { scalarString(one[$0] ?? "") }]
        } else {
            return .failure("JSON must be an array of objects, an array of arrays, or one object.")
        }
        return .success(render(rows, delimiter: delimiter))
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        let csv = "name,note\n\"Doe, Jane\",\"line1\nline2\"\nage,3\n"
        let json = csvToJSON(csv, delimiter: ",", header: true, infer: true)
        expect("csv quoted", json.issue == nil && json.output.contains("Doe, Jane") && json.output.contains("line1\\nline2"))
        expect("csv infer number", json.output.contains("\n    3") || json.output.contains(": 3"))
        let back = jsonToCSV(json.output, delimiter: ",", header: true)
        let again = csvToJSON(back.output, delimiter: ",", header: true, infer: true)
        expect("csv roundtrip", again.issue == nil && again.output.contains("Doe, Jane"))
        let pipes = csvToJSON("a|b\n1|2\n", delimiter: "|", header: true, infer: true)
        expect("csv delimiter", pipes.issue == nil && pipes.output.contains("\"a\"") && pipes.output.contains("1"))
        expect("csv empty", csvToJSON("  ", delimiter: ",", header: true, infer: true).issue != nil)
        expect("csv binary", csvToJSON(String(repeating: "\u{0}", count: 3), delimiter: ",", header: false, infer: false).issue != nil)
        expect("json csv bad", jsonToCSV("{", delimiter: ",", header: true).issue != nil)
    }

    static func parse(_ text: String, delimiter: Character) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var quoted = false
        let characters = Array(text)
        var index = 0
        while index < characters.count {
            let character = characters[index]
            if quoted {
                if character == "\"" {
                    if index + 1 < characters.count, characters[index + 1] == "\"" {
                        field.append("\"")
                        index += 2
                        continue
                    }
                    quoted = false
                    index += 1
                    continue
                }
                field.append(character)
                index += 1
                continue
            }
            if character == "\"" && field.isEmpty {
                quoted = true
                index += 1
                continue
            }
            if character == delimiter {
                row.append(field)
                field = ""
                index += 1
                continue
            }
            if character == "\n" || character == "\r" {
                if character == "\r", index + 1 < characters.count, characters[index + 1] == "\n" {
                    index += 1
                }
                row.append(field)
                field = ""
                rows.append(row)
                row = []
                index += 1
                continue
            }
            field.append(character)
            index += 1
        }
        if quoted { row.append(field) }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }

    static func render(_ rows: [[String]], delimiter: Character) -> String {
        rows.map { row in
            row.map { escape($0, delimiter: delimiter) }.joined(separator: String(delimiter))
        }.joined(separator: "\n")
    }

    private static func escape(_ field: String, delimiter: Character) -> String {
        if field.contains(delimiter) || field.contains("\"") || field.contains("\n") || field.contains("\r") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }

    private static func uniqueKeys(_ header: [String]) -> [String] {
        var seen: [String: Int] = [:]
        return header.map { key in
            let base = key.isEmpty ? "column" : key
            let count = seen[base, default: 0]
            seen[base] = count + 1
            return count == 0 ? base : "\(base)_\(count + 1)"
        }
    }

    private static func inferValue(_ field: String) -> Any {
        let trimmed = field.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return "" }
        if trimmed.caseInsensitiveCompare("true") == .orderedSame { return true }
        if trimmed.caseInsensitiveCompare("false") == .orderedSame { return false }
        if trimmed.caseInsensitiveCompare("null") == .orderedSame { return NSNull() }
        if let int = Int(trimmed), String(int) == trimmed { return int }
        if let double = Double(trimmed), trimmed.contains(".") || trimmed.lowercased().contains("e") {
            return double
        }
        return field
    }

    private static func scalarString(_ value: Any) -> String {
        if value is NSNull { return "" }
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() { return number.boolValue ? "true" : "false" }
            return number.stringValue
        }
        if let string = value as? String { return string }
        if JSONSerialization.isValidJSONObject([value]) || value is NSNumber,
           let data = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed]),
           let text = String(data: data, encoding: .utf8) {
            return text
        }
        return String(describing: value)
    }
}
