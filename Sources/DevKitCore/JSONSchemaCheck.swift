import Foundation

public enum JSONSchemaCheck {
    public static func validate(document: String, schema: String) -> ToolResult {
        if document.utf8.count > 200_000 || schema.utf8.count > 200_000 {
            return .failure("Document and schema must each be under 200 KB.")
        }
        guard let documentData = document.data(using: .utf8),
              let value = try? JSONSerialization.jsonObject(with: documentData, options: [.fragmentsAllowed]) else {
            return .failure("The document is not JSON.")
        }
        guard let schemaData = schema.data(using: .utf8),
              let schemaObject = try? JSONSerialization.jsonObject(with: schemaData) as? [String: Any] else {
            return .failure("The schema is not a JSON object.")
        }
        var issues: [String] = []
        walk(value, schema: schemaObject, path: "$", issues: &issues)
        if issues.isEmpty { return .success("Valid.") }
        return .failure(issues.prefix(30).joined(separator: "\n"))
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        let schema = #"{"type":"object","required":["name"],"properties":{"name":{"type":"string","minLength":2},"role":{"enum":["dev","ops"]}},"additionalProperties":false}"#
        let bad = validate(document: #"{"name":"A","extra":1}"#, schema: schema)
        expect("schema name", bad.issue?.message.contains("$.name") == true)
        expect("schema extra", bad.issue?.message.contains("$.extra") == true)
        let nested = validate(document: #"{"user":{"name":"A"}}"#, schema: #"{"type":"object","properties":{"user":{"type":"object","properties":{"name":{"type":"string","minLength":2}}}}}"#)
        expect("schema path", nested.issue?.message.contains("$.user.name") == true)
        expect("schema ok", validate(document: #"{"name":"Ada","role":"dev"}"#, schema: schema).output == "Valid.")
    }

    private static func walk(_ value: Any, schema: [String: Any], path: String, issues: inout [String]) {
        if issues.count >= 30 { return }
        if let type = schema["type"] as? String, !matches(value, type: type) {
            issues.append("\(path) should be \(type).")
            return
        }
        if let allowed = schema["enum"] as? [Any], !allowed.contains(where: { same($0, value) }) {
            issues.append("\(path) is not one of the allowed values.")
        }
        if let text = value as? String {
            if let minimum = (schema["minLength"] as? NSNumber)?.intValue, text.count < minimum {
                issues.append("\(path) is shorter than \(minimum).")
            }
            if let maximum = (schema["maxLength"] as? NSNumber)?.intValue, text.count > maximum {
                issues.append("\(path) is longer than \(maximum).")
            }
            if let pattern = schema["pattern"] as? String {
                if pattern.count > 200 {
                    issues.append("\(path) pattern is longer than 200 characters.")
                } else if let expression = try? NSRegularExpression(pattern: pattern),
                          expression.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) == nil {
                    issues.append("\(path) does not match \(pattern).")
                } else if (try? NSRegularExpression(pattern: pattern)) == nil {
                    issues.append("\(path) has a pattern that is not a valid regular expression.")
                }
            }
        }
        if let number = jsonNumber(value) {
            if let minimum = schema["minimum"] as? NSNumber, number.doubleValue < minimum.doubleValue {
                issues.append("\(path) is below \(minimum).")
            }
            if let maximum = schema["maximum"] as? NSNumber, number.doubleValue > maximum.doubleValue {
                issues.append("\(path) is above \(maximum).")
            }
        }
        if let object = value as? [String: Any] {
            let properties = schema["properties"] as? [String: Any] ?? [:]
            let required = schema["required"] as? [String] ?? []
            for key in required where object[key] == nil {
                issues.append("\(path).\(key) is required.")
            }
            if schema["additionalProperties"] as? Bool == false {
                for key in object.keys where properties[key] == nil {
                    issues.append("\(path).\(key) is not allowed.")
                }
            }
            for (key, childSchema) in properties {
                guard let child = object[key], let childObject = childSchema as? [String: Any] else { continue }
                walk(child, schema: childObject, path: "\(path).\(key)", issues: &issues)
            }
        }
        if let array = value as? [Any], let itemSchema = schema["items"] as? [String: Any] {
            for (index, item) in array.enumerated() {
                walk(item, schema: itemSchema, path: "\(path)[\(index)]", issues: &issues)
            }
        }
    }

    private static func matches(_ value: Any, type: String) -> Bool {
        switch type {
        case "object": return value is [String: Any]
        case "array": return value is [Any]
        case "string": return value is String
        case "boolean": return isBoolean(value)
        case "null": return value is NSNull
        case "number": return jsonNumber(value) != nil
        case "integer":
            guard let number = jsonNumber(value) else { return false }
            let value = number.doubleValue
            return value.isFinite && value == floor(value)
        default: return false
        }
    }

    private static func jsonNumber(_ value: Any) -> NSNumber? {
        guard let number = value as? NSNumber, !isBoolean(value) else { return nil }
        return number
    }

    private static func isBoolean(_ value: Any) -> Bool {
        guard let number = value as? NSNumber else { return false }
        return CFGetTypeID(number) == CFBooleanGetTypeID()
    }

    private static func same(_ left: Any, _ right: Any) -> Bool {
        if let a = left as? String, let b = right as? String { return a == b }
        if let a = jsonNumber(left), let b = jsonNumber(right) { return a.doubleValue == b.doubleValue }
        if isBoolean(left), isBoolean(right), let a = left as? NSNumber, let b = right as? NSNumber { return a.boolValue == b.boolValue }
        if left is NSNull, right is NSNull { return true }
        return false
    }
}
