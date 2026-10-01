import Foundation

public enum RegexPlayground {
    public struct Hit: Equatable, Sendable {
        public var text: String
        public var groups: [String]
        public var location: Int
        public var length: Int
    }

    public struct Outcome: Equatable, Sendable {
        public var hits: [Hit]
        public var replacement: String
        public var issue: ToolIssue?

        public init(hits: [Hit], replacement: String, issue: ToolIssue?) {
            self.hits = hits
            self.replacement = replacement
            self.issue = issue
        }
    }

    public static let library: [(name: String, pattern: String)] = [
        ("Email", "[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}"),
        ("URL", "https?://[^\\s]+"),
        ("IPv4", "\\b(?:\\d{1,3}\\.){3}\\d{1,3}\\b"),
        ("Hex color", "#(?:[0-9A-Fa-f]{3}|[0-9A-Fa-f]{6})\\b"),
        ("ISO date", "\\d{4}-\\d{2}-\\d{2}"),
        ("Quoted string", "\"(?:\\\\.|[^\"\\\\])*\""),
    ]

    public static func run(pattern: String, text: String, template: String, caseInsensitive: Bool, anchorsMatchLines: Bool, dotMatchesLines: Bool) -> Outcome {
        if pattern.isEmpty { return Outcome(hits: [], replacement: text, issue: ToolIssue(message: "Enter a pattern.")) }
        if text.count > 2_000_000 { return Outcome(hits: [], replacement: "", issue: ToolIssue(message: "Text is larger than 2 MB.")) }
        var options: NSRegularExpression.Options = []
        if caseInsensitive { options.insert(.caseInsensitive) }
        if anchorsMatchLines { options.insert(.anchorsMatchLines) }
        if dotMatchesLines { options.insert(.dotMatchesLineSeparators) }
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: options)
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = regex.matches(in: text, range: range)
            var hits: [Hit] = []
            hits.reserveCapacity(min(matches.count, 2000))
            for match in matches.prefix(2000) {
                var groups: [String] = []
                if match.numberOfRanges > 1 {
                    for index in 1..<match.numberOfRanges {
                        groups.append(substring(text, match.range(at: index)) ?? "")
                    }
                }
                hits.append(Hit(
                    text: substring(text, match.range) ?? "",
                    groups: groups,
                    location: match.range.location,
                    length: match.range.length
                ))
            }
            let replaced = regex.stringByReplacingMatches(in: text, range: range, withTemplate: template)
            var issue: ToolIssue?
            if matches.count > 2000 {
                issue = ToolIssue(message: "Showing the first 2000 matches of \(matches.count).")
            }
            return Outcome(hits: hits, replacement: replaced, issue: issue)
        } catch {
            return Outcome(hits: [], replacement: "", issue: ToolIssue(message: error.localizedDescription))
        }
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        let outcome = run(pattern: #"(\w+)@(\w+)"#, text: "a@b and c@d", template: "[$1]", caseInsensitive: false, anchorsMatchLines: false, dotMatchesLines: false)
        expect("regex groups", outcome.hits.count == 2 && outcome.hits[0].groups == ["a", "b"])
        expect("regex replace", outcome.replacement == "[a] and [c]")
        let flags = run(pattern: "a.b", text: "a\nb", template: "x", caseInsensitive: false, anchorsMatchLines: false, dotMatchesLines: true)
        expect("regex dot line", flags.hits.count == 1)
        expect("regex bad", run(pattern: "(", text: "a", template: "", caseInsensitive: false, anchorsMatchLines: false, dotMatchesLines: false).issue != nil)
        expect("regex empty pattern", run(pattern: "", text: "a", template: "", caseInsensitive: false, anchorsMatchLines: false, dotMatchesLines: false).issue != nil)
    }

    private static func substring(_ text: String, _ range: NSRange) -> String? {
        guard range.location != NSNotFound, let swift = Range(range, in: text) else { return nil }
        return String(text[swift])
    }
}
