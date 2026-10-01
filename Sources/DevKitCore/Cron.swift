import Foundation

public enum Cron {
    public static func explain(_ expression: String, now: Date = Date(), timeZone: TimeZone = TimeZone(secondsFromGMT: 0) ?? .current) -> ToolResult {
        let trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .failure("Enter a 5-field cron expression.") }
        if trimmed.count > 200 { return .failure("That expression is too long.") }
        let fields: Fields
        do { fields = try parse(trimmed) } catch let issue as ToolIssue { return .failure(issue) } catch { return .failure(error.localizedDescription) }
        let runs = nextRuns(fields, from: now, count: 10, timeZone: timeZone)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let lines = runs.enumerated().map { "\($0.offset + 1). \(formatter.string(from: $0.element))" }
        return .success(([describe(fields), "", "Next 10 runs:"] + lines).joined(separator: "\n"))
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        let zone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let start = calendar.date(from: DateComponents(timeZone: zone, year: 2020, month: 1, day: 1, hour: 0, minute: 0))!
        let daily = explain("0 0 * * *", now: start, timeZone: zone)
        expect("cron daily english", daily.output.contains("minute 0") && daily.output.contains("hour 0"))
        expect("cron next midnight", daily.output.contains("2020-01-02 00:00"))
        let steps = explain("*/15 * * * *", now: start, timeZone: zone)
        expect("cron step", steps.output.contains("2020-01-01 00:15") && steps.output.contains("2020-01-01 00:30"))
        expect("cron bad", explain("60 * * * *").issue != nil)
        expect("cron empty", explain("  ").issue != nil)
        expect("cron fields", explain("* * *").issue != nil)
        let built = explain(build(minute: "0", hour: "12", day: "*", month: "*", weekday: "1"), now: start, timeZone: zone)
        expect("cron monday noon", built.output.contains("2020-01-06 12:00"))
    }

    public static func build(minute: String, hour: String, day: String, month: String, weekday: String) -> String {
        [minute, hour, day, month, weekday].map { $0.trimmingCharacters(in: .whitespaces).isEmpty ? "*" : $0.trimmingCharacters(in: .whitespaces) }.joined(separator: " ")
    }

    private struct Fields {
        var minute: Set<Int>
        var hour: Set<Int>
        var day: Set<Int>
        var month: Set<Int>
        var weekday: Set<Int>
        var dayStar: Bool
        var weekdayStar: Bool
    }

    private static func parse(_ text: String) throws -> Fields {
        let parts = text.split(whereSeparator: \.isWhitespace).map(String.init)
        guard parts.count == 5 else { throw ToolIssue(message: "Cron needs 5 fields: minute hour day month weekday.") }
        return Fields(
            minute: try field(parts[0], 0, 59, "minute"),
            hour: try field(parts[1], 0, 23, "hour"),
            day: try field(parts[2], 1, 31, "day"),
            month: try field(parts[3], 1, 12, "month"),
            weekday: try weekday(parts[4]),
            dayStar: parts[2] == "*",
            weekdayStar: parts[4] == "*"
        )
    }

    private static func field(_ text: String, _ low: Int, _ high: Int, _ name: String) throws -> Set<Int> {
        if text == "*" { return Set(low...high) }
        var values = Set<Int>()
        for part in text.split(separator: ",") {
            let piece = String(part)
            let stepParts = piece.split(separator: "/", maxSplits: 1).map(String.init)
            let step = stepParts.count == 2 ? Int(stepParts[1]) ?? -1 : 1
            guard step > 0 else { throw ToolIssue(message: "Invalid step in \(name).") }
            let span = stepParts[0]
            let start: Int
            let end: Int
            if span == "*" {
                start = low
                end = high
            } else if span.contains("-") {
                let bounds = span.split(separator: "-").map(String.init)
                guard bounds.count == 2, let lhs = Int(bounds[0]), let rhs = Int(bounds[1]), lhs <= rhs else {
                    throw ToolIssue(message: "Invalid range in \(name).")
                }
                start = lhs
                end = rhs
            } else if let value = Int(span) {
                start = value
                end = value
            } else {
                throw ToolIssue(message: "Invalid \(name) field \"\(text)\".")
            }
            guard start >= low, end <= high else { throw ToolIssue(message: "\(name) must be from \(low) to \(high).") }
            var cursor = start
            while cursor <= end {
                values.insert(cursor)
                cursor += step
            }
        }
        if values.isEmpty { throw ToolIssue(message: "\(name) matched no values.") }
        return values
    }

    private static func weekday(_ text: String) throws -> Set<Int> {
        var values = try field(text, 0, 7, "weekday")
        if values.contains(7) {
            values.remove(7)
            values.insert(0)
        }
        return values
    }

    private static func describe(_ fields: Fields) -> String {
        "At minute \(list(fields.minute)), hour \(list(fields.hour)), day \(fields.dayStar ? "every day of the month" : list(fields.day)), month \(list(fields.month)), weekday \(fields.weekdayStar ? "every weekday slot" : list(fields.weekday)) (0 and 7 are Sunday). If both day and weekday are restricted, a date matches when either field matches."
    }

    private static func list(_ values: Set<Int>) -> String {
        let sorted = values.sorted()
        if sorted.count > 12 { return "\(sorted.first ?? 0)–\(sorted.last ?? 0) (\(sorted.count) values)" }
        return sorted.map(String.init).joined(separator: ",")
    }

    private static func nextRuns(_ fields: Fields, from date: Date, count: Int, timeZone: TimeZone) -> [Date] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let start = calendar.date(bySetting: .second, value: 0, of: date) ?? date
        guard var cursor = calendar.date(byAdding: .minute, value: 1, to: start) else { return [] }
        var found: [Date] = []
        var steps = 0
        while found.count < count && steps < 1_100_000 {
            let parts = calendar.dateComponents([.minute, .hour, .day, .month, .weekday], from: cursor)
            let minute = parts.minute ?? -1
            let hour = parts.hour ?? -1
            let day = parts.day ?? -1
            let month = parts.month ?? -1
            let weekday = parts.weekday ?? 1
            let cronWeekday = weekday - 1
            let dayOK = fields.dayStar || fields.day.contains(day)
            let weekOK = fields.weekdayStar || fields.weekday.contains(cronWeekday)
            let dayMatch = fields.dayStar || fields.weekdayStar ? dayOK && weekOK : dayOK || weekOK
            if fields.minute.contains(minute), fields.hour.contains(hour), fields.month.contains(month), dayMatch {
                found.append(cursor)
            }
            guard let next = calendar.date(byAdding: .minute, value: 1, to: cursor) else { break }
            cursor = next
            steps += 1
        }
        return found
    }
}
