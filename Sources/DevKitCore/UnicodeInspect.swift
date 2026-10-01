import Foundation

public enum UnicodeInspect {
    public static func describe(_ text: String) -> ToolResult {
        if text.count > 20_000 { return .failure("Paste at most 20,000 characters.") }
        if text.isEmpty { return .success("") }
        var lines: [String] = []
        lines.reserveCapacity(text.unicodeScalars.count)
        for scalar in text.unicodeScalars {
            lines.append(line(scalar))
        }
        return .success(lines.joined(separator: "\n"))
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        let latin = describe("A")
        expect("unicode latin", latin.output.contains("U+0041") && latin.output.contains("LATIN CAPITAL LETTER A"))
        let euro = describe("€")
        expect("unicode euro", euro.output.contains("U+20AC"))
        expect("unicode empty", describe("").output.isEmpty && describe("").issue == nil)
        expect("unicode cap", describe(String(repeating: "a", count: 20_001)).issue != nil)
    }

    private static func line(_ scalar: Unicode.Scalar) -> String {
        let code = String(format: "U+%04X", scalar.value)
        let name = scalar.properties.name ?? scalar.properties.nameAlias ?? "unnamed"
        let bytes = scalar.utf8.map { String(format: "%02X", $0) }.joined(separator: " ")
        return "\(code)\t\(name)\t\(scalar.properties.generalCategory)\tUTF-8 \(bytes)"
    }
}
