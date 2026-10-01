import Foundation

public enum HexDump {
    public static func dump(text: String, hexInput: Bool, highlightStart: Int, highlightLength: Int) -> ToolResult {
        if text.utf8.count > 2_000_000 { return .failure("Input is larger than 2 MB.") }
        let data: Data
        if hexInput {
            switch parseHex(text) {
            case let .success(value): data = value
            case let .failure(issue): return .failure(issue)
            }
        } else {
            if text.utf8.contains(0) { return .failure("Input looks like binary data. Open the file instead.") }
            data = Data(text.utf8)
        }
        return dump(data: data, highlightStart: highlightStart, highlightLength: highlightLength)
    }

    public static func dump(data: Data, highlightStart: Int, highlightLength: Int) -> ToolResult {
        if data.count > 2_000_000 { return .failure("File is larger than 2 MB.") }
        let start = min(max(0, highlightStart), data.count)
        let end = highlightLength > 0 ? start + min(highlightLength, data.count - start) : start
        var lines: [String] = []
        var offset = 0
        while offset < data.count || data.isEmpty {
            let chunk = data[offset..<min(offset + 16, data.count)]
            var cells: [String] = []
            var ascii = ""
            for (index, byte) in chunk.enumerated() {
                let marked = offset + index >= start && offset + index < end
                let token = String(format: "%02X", byte)
                cells.append(marked ? "[\(token)]" : " \(token) ")
                ascii.append(byte >= 32 && byte < 127 ? Character(UnicodeScalar(byte)) : ".")
            }
            while cells.count < 16 { cells.append("    ") }
            let hex = cells.prefix(8).joined() + " " + cells.suffix(8).joined()
            lines.append(String(format: "%08X  %@  %@", offset, hex, ascii))
            offset += 16
            if data.isEmpty { break }
        }
        return .success(lines.joined(separator: "\n"))
    }

    public static func parseHex(_ text: String) -> Result<Data, ToolIssue> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .success(Data()) }
        if trimmed.unicodeScalars.contains(where: { CharacterSet.whitespacesAndNewlines.contains($0) }) {
            return parseHexTokens(trimmed)
        }
        return parseHexRun(String(trimmed.unicodeScalars.filter { $0 != "," && $0 != ":" }))
    }

    private static func parseHexTokens(_ text: String) -> Result<Data, ToolIssue> {
        var data = Data()
        var sawByte = false
        for rawLine in text.split(whereSeparator: \.isNewline) {
            let parts = rawLine.split(whereSeparator: \.isWhitespace)
            for (index, part) in parts.enumerated() {
                let token = String(part).trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                if index == 0, token.count == 8, isHex(token) { continue }
                if token.count == 2, isHex(token), let byte = UInt8(token, radix: 16) {
                    data.append(byte)
                    sawByte = true
                    continue
                }
                if token.count > 2, token.count % 2 == 0, isHex(token) {
                    switch parseHexRun(token) {
                    case let .success(value):
                        data.append(value)
                        sawByte = true
                    case let .failure(issue):
                        return .failure(issue)
                    }
                    continue
                }
            }
        }
        if !sawByte { return .failure(ToolIssue(message: "No hex bytes found. Use pairs such as 48 65, or switch the input to Text.")) }
        return .success(data)
    }

    private static func parseHexRun(_ text: String) -> Result<Data, ToolIssue> {
        let cleaned = text.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) }
        if cleaned.isEmpty { return .success(Data()) }
        if cleaned.contains(where: { !isHex(String($0)) }) {
            return .failure(ToolIssue(message: "Hex input has a character that is not 0-9 or A-F."))
        }
        if cleaned.count % 2 != 0 { return .failure(ToolIssue(message: "Hex input needs an even number of digits.")) }
        var data = Data()
        data.reserveCapacity(cleaned.count / 2)
        var index = cleaned.startIndex
        while index < cleaned.endIndex {
            let next = cleaned.index(index, offsetBy: 2)
            let pair = String(cleaned[index..<next])
            guard let byte = UInt8(pair, radix: 16) else {
                return .failure(ToolIssue(message: "Could not read hex byte \(pair)."))
            }
            data.append(byte)
            index = next
        }
        return .success(data)
    }

    private static func isHex(_ text: String) -> Bool {
        let digits = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        return !text.isEmpty && text.unicodeScalars.allSatisfy { digits.contains($0) }
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        let dumped = dump(text: "Hi", hexInput: false, highlightStart: 0, highlightLength: 1)
        expect("hex hi", dumped.output.contains("[48]") && dumped.output.contains("Hi"))
        expect("hex bad", dump(text: "zz", hexInput: true, highlightStart: 0, highlightLength: 0).issue != nil)
        expect("hex spaced", dump(text: "48 65 6c 6c 6f", hexInput: true, highlightStart: 0, highlightLength: 0).output.contains("Hello"))
        expect("hex huge", dump(text: "Hi", hexInput: false, highlightStart: 2, highlightLength: Int.max).output.contains("Hi"))
        if case .failure = parseHex("-ff") { expect("hex dash", true) } else { expect("hex dash", false) }
    }
}
