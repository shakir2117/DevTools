import Foundation

public enum TimestampConvert {
    public enum UnitMode: String, CaseIterable, Sendable {
        case auto, seconds, milliseconds

        public var title: String {
            switch self {
            case .auto: return "Auto"
            case .seconds: return "Seconds"
            case .milliseconds: return "Milliseconds"
            }
        }
    }

    public static let commonZones = [
        "UTC", "local",
        "America/New_York", "America/Chicago", "America/Denver", "America/Los_Angeles",
        "Europe/London", "Europe/Paris", "Europe/Berlin",
        "Asia/Kolkata", "Asia/Shanghai", "Asia/Tokyo",
        "Australia/Sydney", "Pacific/Auckland",
    ]

    public static func convert(_ text: String, unit: UnitMode, timeZoneID: String, now: Date = Date()) -> ToolResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .failure("Enter a unix timestamp, an ISO 8601 date, or now.") }
        if trimmed.count > 200 { return .failure("That input is too long to be a timestamp.") }
        if trimmed.utf8.contains(0) { return .failure("Input looks like binary data.") }
        guard let zone = resolveZone(timeZoneID) else {
            return .failure("Unknown time zone \"\(timeZoneID)\".")
        }
        let date: Date
        if trimmed.caseInsensitiveCompare("now") == .orderedSame {
            date = now
        } else if let value = Double(trimmed), value.isFinite {
            let asMilliseconds: Bool
            switch unit {
            case .milliseconds: asMilliseconds = true
            case .seconds: asMilliseconds = false
            case .auto: asMilliseconds = abs(value) >= 100_000_000_000
            }
            date = Date(timeIntervalSince1970: asMilliseconds ? value / 1000 : value)
        } else if let parsed = parseDate(trimmed, timeZone: zone) {
            date = parsed
        } else {
            return .failure("Could not parse that timestamp.")
        }
        let unix = date.timeIntervalSince1970
        let lines = [
            "ISO 8601: \(formatISO(date, timeZone: TimeZone(secondsFromGMT: 0) ?? zone))",
            "Local: \(formatISO(date, timeZone: zone))",
            "Time zone: \(zone.identifier)",
            "Unix seconds: \(formatNumber(unix))",
            "Unix milliseconds: \(formatNumber(unix * 1000))",
            "Relative: \(relative(date, now: now))",
        ]
        return .success(lines.joined(separator: "\n"))
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        let epoch = convert("0", unit: .seconds, timeZoneID: "UTC", now: Date(timeIntervalSince1970: 120))
        expect("timestamp epoch", epoch.output.contains("1970-01-01T00:00:00Z") && epoch.issue == nil)
        let fromISO = convert("1970-01-01T00:00:00Z", unit: .auto, timeZoneID: "UTC", now: Date(timeIntervalSince1970: 10))
        expect("timestamp iso", fromISO.output.contains("Unix seconds: 0"))
        let clock = Date(timeIntervalSince1970: 1_700_000_000)
        let ahead = convert(String(clock.addingTimeInterval(120).timeIntervalSince1970), unit: .seconds, timeZoneID: "UTC", now: clock)
        expect("timestamp future", ahead.output.contains("in 2 minutes"))
        let past = convert(String(clock.addingTimeInterval(-120).timeIntervalSince1970), unit: .seconds, timeZoneID: "UTC", now: clock)
        expect("timestamp ago", past.output.contains("2 minutes ago"))
        let millis = convert("1000", unit: .milliseconds, timeZoneID: "UTC", now: Date(timeIntervalSince1970: 10))
        expect("timestamp millis", millis.output.contains("Unix seconds: 1"))
        expect("timestamp empty", convert("  ", unit: .auto, timeZoneID: "UTC").issue != nil)
        expect("timestamp bad", convert("not-a-date", unit: .auto, timeZoneID: "UTC").issue != nil)
        expect("timestamp binary", convert(String(repeating: "\u{0}", count: 3), unit: .auto, timeZoneID: "UTC").issue != nil)
    }

    private static func resolveZone(_ identifier: String) -> TimeZone? {
        if identifier == "local" { return .current }
        return TimeZone(identifier: identifier)
    }

    private static func parseDate(_ text: String, timeZone: TimeZone) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.timeZone = TimeZone(secondsFromGMT: 0)
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: text) { return date }
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: text) { return date }
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd",
            "MM/dd/yyyy HH:mm:ss",
            "MM/dd/yyyy",
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

    private static func formatISO(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = timeZone
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private static func formatNumber(_ value: TimeInterval) -> String {
        if value.rounded() == value, abs(value) < 1e15 {
            return String(format: "%.0f", value)
        }
        return String(value)
    }

    private static func relative(_ date: Date, now: Date) -> String {
        let delta = date.timeIntervalSince(now)
        let seconds = Int(delta.rounded())
        let past = seconds < 0
        let amount = abs(seconds)
        let (value, unit): (Int, String)
        if amount < 60 {
            (value, unit) = (amount, amount == 1 ? "second" : "seconds")
        } else if amount < 3600 {
            let minutes = amount / 60
            (value, unit) = (minutes, minutes == 1 ? "minute" : "minutes")
        } else if amount < 86_400 {
            let hours = amount / 3600
            (value, unit) = (hours, hours == 1 ? "hour" : "hours")
        } else {
            let days = amount / 86_400
            (value, unit) = (days, days == 1 ? "day" : "days")
        }
        if value == 0 { return "now" }
        return past ? "\(value) \(unit) ago" : "in \(value) \(unit)"
    }
}
