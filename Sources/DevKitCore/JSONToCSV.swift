import Foundation

public enum JSONToCSV {
    public static func convert(_ text: String, delimiter: Character = ",") -> ToolResult {
        if text.count > 8_000_000 { return .failure("JSON is larger than 8 MB.") }
        if let issue = InputChecks.issue(for: text, emptyPrompt: "Enter JSON to flatten into CSV.") {
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
        let records: [Any]
        if let array = object as? [Any] {
            records = array
        } else {
            records = [object]
        }
        var rows: [[String: String]] = []
        var keys: [String] = []
        var seen = Set<String>()
        for record in records {
            var row: [String: String] = [:]
            flatten(record, prefix: "", into: &row)
            for key in row.keys.sorted() where seen.insert(key).inserted {
                keys.append(key)
            }
            rows.append(row)
        }
        if rows.isEmpty { return .success("") }
        var table: [[String]] = [keys]
        for row in rows {
            table.append(keys.map { row[$0] ?? "" })
        }
        return .success(CSVJSON.render(table, delimiter: delimiter))
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        let json = #"[{"user":{"name":"Ada","id":1},"tags":["a","b"]},{"user":{"name":"Bea"}}]"#
        let csv = convert(json)
        expect("json csv header", csv.issue == nil && csv.output.hasPrefix("tags.0,tags.1,user.id,user.name"))
        expect("json csv values", csv.output.contains("Ada") && csv.output.contains("Bea"))
        let back = CSVJSON.csvToJSON(csv.output, delimiter: ",", header: true, infer: false)
        expect("json csv roundtrip cells", back.issue == nil && back.output.contains("Ada") && back.output.contains("user.name"))
        expect("json csv empty", convert(" ").issue != nil)
        expect("json csv bad", convert("{").issue != nil)
    }

    private static func flatten(_ value: Any, prefix: String, into row: inout [String: String]) {
        if let object = value as? [String: Any] {
            if object.isEmpty, !prefix.isEmpty { row[prefix] = "" }
            for key in object.keys.sorted() {
                let next = prefix.isEmpty ? key : "\(prefix).\(key)"
                flatten(object[key] as Any, prefix: next, into: &row)
            }
            return
        }
        if let array = value as? [Any] {
            if array.isEmpty, !prefix.isEmpty { row[prefix] = "" }
            for (index, item) in array.enumerated() {
                let next = prefix.isEmpty ? "\(index)" : "\(prefix).\(index)"
                flatten(item, prefix: next, into: &row)
            }
            return
        }
        let key = prefix.isEmpty ? "value" : prefix
        row[key] = scalar(value)
    }

    private static func scalar(_ value: Any) -> String {
        if value is NSNull { return "" }
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() { return number.boolValue ? "true" : "false" }
            return number.stringValue
        }
        if let string = value as? String { return string }
        return String(describing: value)
    }
}
