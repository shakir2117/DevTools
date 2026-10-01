import Foundation

public enum DateConvert {
    public enum OutputStyle: String, CaseIterable, Sendable {
        case iso8601, rfc2822, custom

        public var title: String {
            switch self {
            case .iso8601: return "ISO 8601"
            case .rfc2822: return "RFC 2822"
            case .custom: return "Custom"
            }
        }
    }

    public static func convert(
        text: String,
        other: String,
        style: OutputStyle,
        customFormat: String,
        timeZoneID: String,
        now: Date = Date()
    ) -> ToolResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .failure("Enter a date.") }
        if trimmed.count > 200 { return .failure("That input is too long to be a date.") }
        guard let zone = timeZoneID == "local" ? TimeZone.current : TimeZone(identifier: timeZoneID) else {
            return .failure("Unknown time zone \"\(timeZoneID)\".")
        }
        guard let date = parse(trimmed, timeZone: zone, now: now) else {
            return .failure("Could not parse that date.")
        }
        var lines = ["Output: \(render(date, style: style, customFormat: customFormat, timeZone: zone))"]
        lines.append("ISO 8601: \(render(date, style: .iso8601, customFormat: "", timeZone: TimeZone(secondsFromGMT: 0) ?? zone))")
        lines.append("RFC 2822: \(render(date, style: .rfc2822, customFormat: "", timeZone: zone))")
        let otherTrimmed = other.trimmingCharacters(in: .whitespacesAndNewlines)
        if !otherTrimmed.isEmpty {
            guard let second = parse(otherTrimmed, timeZone: zone, now: now) else {
                return .failure("Could not parse the second date.")
            }
            lines.append("Difference: \(difference(from: date, to: second))")
        }
        return .success(lines.joined(separator: "\n"))
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        let iso = convert(text: "2020-01-02T03:04:05Z", other: "", style: .rfc2822, customFormat: "", timeZoneID: "UTC")
        expect("date rfc", iso.issue == nil && iso.output.contains("Thu, 02 Jan 2020 03:04:05 +0000"))
        let custom = convert(text: "2020-01-02", other: "", style: .custom, customFormat: "yyyy/MM/dd", timeZoneID: "UTC")
        expect("date custom", custom.output.contains("Output: 2020/01/02"))
        let diff = convert(text: "2020-01-01T00:00:00Z", other: "2020-01-03T00:00:00Z", style: .iso8601, customFormat: "", timeZoneID: "UTC")
        expect("date difference", diff.output.contains("2 days"))
        let unix = convert(text: "0", other: "", style: .iso8601, customFormat: "", timeZoneID: "UTC")
        expect("date unix", unix.output.contains("1970-01-01T00:00:00Z"))
        expect("date empty", convert(text: " ", other: "", style: .iso8601, customFormat: "", timeZoneID: "UTC").issue != nil)
        expect("date bad", convert(text: "not-a-date", other: "", style: .iso8601, customFormat: "", timeZoneID: "UTC").issue != nil)
    }

    private static func parse(_ text: String, timeZone: TimeZone, now: Date) -> Date? {
        if text.caseInsensitiveCompare("now") == .orderedSame { return now }
        if let value = Double(text), value.isFinite, text.allSatisfy({ $0.isNumber || $0 == "." || $0 == "-" }) {
            let seconds = abs(value) >= 100_000_000_000 ? value / 1000 : value
            return Date(timeIntervalSince1970: seconds)
        }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: text) { return date }
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: text) { return date }
        let formats = [
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd",
            "MM/dd/yyyy HH:mm:ss",
            "MM/dd/yyyy",
            "dd/MM/yyyy",
            "MMM d, yyyy",
            "MMMM d, yyyy",
            "yyyy/MM/dd",
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }

    private static func render(_ date: Date, style: OutputStyle, customFormat: String, timeZone: TimeZone) -> String {
        switch style {
        case .iso8601:
            let formatter = ISO8601DateFormatter()
            formatter.timeZone = timeZone
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.string(from: date)
        case .rfc2822:
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = timeZone
            formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
            return formatter.string(from: date)
        case .custom:
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = timeZone
            formatter.dateFormat = customFormat.isEmpty ? "yyyy-MM-dd HH:mm:ss" : customFormat
            return formatter.string(from: date)
        }
    }

    private static func difference(from start: Date, to end: Date) -> String {
        let seconds = Int(end.timeIntervalSince(start).rounded())
        let sign = seconds < 0 ? "-" : ""
        var amount = abs(seconds)
        let days = amount / 86_400
        amount %= 86_400
        let hours = amount / 3600
        amount %= 3600
        let minutes = amount / 60
        let secs = amount % 60
        var parts: [String] = []
        if days != 0 { parts.append("\(days) \(days == 1 ? "day" : "days")") }
        if hours != 0 { parts.append("\(hours) \(hours == 1 ? "hour" : "hours")") }
        if minutes != 0 { parts.append("\(minutes) \(minutes == 1 ? "minute" : "minutes")") }
        if secs != 0 || parts.isEmpty { parts.append("\(secs) \(secs == 1 ? "second" : "seconds")") }
        return sign + parts.joined(separator: " ")
    }
}
