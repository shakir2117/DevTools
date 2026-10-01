import Foundation

public enum FileSizeCalc {
    public static let units = ["B", "KB", "MB", "GB", "TB", "PB", "KiB", "MiB", "GiB", "TiB", "PiB"]

    public static func convert(text: String, unit: String) -> ToolResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .failure("Enter a file size.") }
        if trimmed.count > 100 { return .failure("That number is too long.") }
        guard let value = Double(trimmed), value.isFinite, value >= 0 else {
            return .failure("Enter a non-negative number.")
        }
        guard let bytes = bytes(value, unit: unit) else { return .failure("Unknown unit \(unit).") }
        let si = ["B", "KB", "MB", "GB", "TB", "PB"]
        let iec = ["B", "KiB", "MiB", "GiB", "TiB", "PiB"]
        var lines = ["Bytes: \(format(bytes))", "", "SI (1000)"]
        for (index, name) in si.enumerated() {
            lines.append("\(name): \(format(bytes / pow(1000, Double(index))))")
        }
        lines.append("")
        lines.append("IEC (1024)")
        for (index, name) in iec.enumerated() {
            lines.append("\(name): \(format(bytes / pow(1024, Double(index))))")
        }
        return .success(lines.joined(separator: "\n"))
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        let kib = convert(text: "1", unit: "KiB")
        expect("size kib", kib.output.contains("Bytes: 1024") && kib.output.contains("SI (1000)") && kib.output.contains("IEC (1024)"))
        let kb = convert(text: "1", unit: "KB")
        expect("size kb", kb.output.contains("Bytes: 1000"))
        let round = convert(text: "1.5", unit: "MiB")
        expect("size mib", round.output.contains("Bytes: 1572864"))
        expect("size empty", convert(text: " ", unit: "B").issue != nil)
        expect("size negative", convert(text: "-1", unit: "B").issue != nil)
        expect("size bad", convert(text: "nope", unit: "MB").issue != nil)
    }

    private static func bytes(_ value: Double, unit: String) -> Double? {
        switch unit {
        case "B": return value
        case "KB": return value * 1_000
        case "MB": return value * 1_000_000
        case "GB": return value * 1_000_000_000
        case "TB": return value * 1_000_000_000_000
        case "PB": return value * 1_000_000_000_000_000
        case "KiB": return value * 1024
        case "MiB": return value * 1_048_576
        case "GiB": return value * 1_073_741_824
        case "TiB": return value * 1_099_511_627_776
        case "PiB": return value * 1_125_899_906_842_624
        default: return nil
        }
    }

    private static func format(_ value: Double) -> String {
        if abs(value) >= 1e15 || (value != 0 && abs(value) < 0.0001) { return String(value) }
        if value.rounded() == value { return String(format: "%.0f", value) }
        let text = String(format: "%.6f", value)
        var trimmed = text
        while trimmed.contains("."), trimmed.last == "0" { trimmed.removeLast() }
        if trimmed.last == "." { trimmed.removeLast() }
        return trimmed
    }
}
