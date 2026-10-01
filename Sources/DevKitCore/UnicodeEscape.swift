import Foundation

public enum UnicodeEscape {
    public enum Form: String {
        case json
        case html
        case url
    }

    public static func encode(_ text: String, form: Form) -> ToolResult {
        if let issue = bounded(text) { return .failure(issue) }
        switch form {
        case .json:
            return .success(text.unicodeScalars.map(jsonScalar).joined())
        case .html:
            return .success(text.unicodeScalars.map(htmlScalar).joined())
        case .url:
            return .success(percent(Data(text.utf8)))
        }
    }

    public static func decode(_ text: String, form: Form) -> ToolResult {
        if let issue = bounded(text) { return .failure(issue) }
        switch form {
        case .json:
            return decodeJSON(text)
        case .html:
            return decodeHTML(text)
        case .url:
            return decodeURL(text)
        }
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        expect("escape json", encode("é", form: .json).output == "\\u00E9")
        expect("escape html", encode("é", form: .html).output == "&#xE9;")
        expect("escape url", encode("é", form: .url).output == "%C3%A9")
        expect("escape quote", encode("\"", form: .json).output == "\\\"")
        expect("escape back", decode("\\u00E9", form: .json).output == "é")
        expect("escape huge", encode(String(repeating: "a", count: 100_001), form: .json).issue != nil)
    }

    private static func bounded(_ text: String) -> ToolIssue? {
        if text.utf8.count > 100_000 { return ToolIssue(message: "Input is larger than 100,000 characters.") }
        if text.utf8.contains(0) { return ToolIssue(message: "Input looks like binary data.") }
        return nil
    }

    private static func jsonScalar(_ scalar: UnicodeScalar) -> String {
        switch scalar {
        case "\\": return "\\\\"
        case "\"": return "\\\""
        case "\n": return "\\n"
        case "\r": return "\\r"
        case "\t": return "\\t"
        default:
            if scalar.value >= 32 && scalar.value <= 126 { return String(scalar) }
            if scalar.value <= 0xFFFF { return String(format: "\\u%04X", scalar.value) }
            let rest = scalar.value - 0x10000
            return String(format: "\\u%04X\\u%04X", 0xD800 + (rest >> 10), 0xDC00 + (rest & 0x3FF))
        }
    }

    private static func htmlScalar(_ scalar: UnicodeScalar) -> String {
        if scalar.value < 128 && scalar != "<" && scalar != ">" && scalar != "&" && scalar != "\"" {
            return String(scalar)
        }
        return String(format: "&#x%X;", scalar.value)
    }

    private static func percent(_ data: Data) -> String {
        data.map { byte in
            let unreserved = (byte >= 48 && byte <= 57) || (byte >= 65 && byte <= 90) || (byte >= 97 && byte <= 122) || byte == 45 || byte == 46 || byte == 95 || byte == 126
            return unreserved ? String(UnicodeScalar(byte)) : String(format: "%%%02X", byte)
        }.joined()
    }

    private static func decodeJSON(_ text: String) -> ToolResult {
        var result = ""
        let scalars = Array(text.unicodeScalars)
        var index = 0
        while index < scalars.count {
            let scalar = scalars[index]
            if scalar != "\\" {
                result.unicodeScalars.append(scalar)
                index += 1
                continue
            }
            guard index + 1 < scalars.count else { return .failure("A backslash is missing its escape.") }
            let next = scalars[index + 1]
            switch next {
            case "n": result.append("\n"); index += 2
            case "r": result.append("\r"); index += 2
            case "t": result.append("\t"); index += 2
            case "\\", "\"", "/": result.unicodeScalars.append(next); index += 2
            case "u":
                guard index + 5 < scalars.count else { return .failure("A \\u escape is incomplete.") }
                let hex = scalars[index + 2...index + 5].map { String($0) }.joined()
                guard let value = UInt32(hex, radix: 16), let decoded = UnicodeScalar(value) else {
                    return .failure("\\u\(hex) is not a code point.")
                }
                result.unicodeScalars.append(decoded)
                index += 6
            default:
                return .failure("\\\(next) is not a JSON escape.")
            }
        }
        return .success(result)
    }

    private static func decodeHTML(_ text: String) -> ToolResult {
        var result = ""
        var rest = text[...]
        while let mark = rest.range(of: "&#x") {
            result += rest[..<mark.lowerBound]
            let digits = rest[mark.upperBound...]
            guard let end = digits.firstIndex(of: ";"), let value = UInt32(digits[..<end], radix: 16), let scalar = UnicodeScalar(value) else {
                return .failure("An HTML numeric escape is incomplete.")
            }
            result.unicodeScalars.append(scalar)
            rest = digits[digits.index(after: end)...]
        }
        result += rest
        return .success(result)
    }

    private static func decodeURL(_ text: String) -> ToolResult {
        var data = Data()
        let scalars = Array(text.unicodeScalars)
        var index = 0
        while index < scalars.count {
            if scalars[index] == "%" {
                guard index + 2 < scalars.count else { return .failure("A percent escape is incomplete.") }
                let hex = scalars[index + 1...index + 2].map { String($0) }.joined()
                guard let byte = UInt8(hex, radix: 16) else { return .failure("%\(hex) is not a byte.") }
                data.append(byte)
                index += 3
            } else {
                guard let encoded = String(scalars[index]).utf8.first else { return .failure("That character cannot be decoded.") }
                data.append(encoded)
                index += 1
            }
        }
        guard let text = String(data: data, encoding: .utf8) else { return .failure("The percent escapes are not UTF-8.") }
        return .success(text)
    }
}
