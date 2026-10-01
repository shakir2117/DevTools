import Foundation

public enum TextDiff {
    public enum Granularity: String, Sendable {
        case line, word, character
    }

    public struct Row: Equatable, Sendable {
        public var left: String
        public var right: String
        public var kind: String
    }

    public static func diff(_ left: String, _ right: String, granularity: Granularity, ignoreWhitespace: Bool, ignoreCase: Bool) -> (unified: String, rows: [Row]) {
        let lhs = pieces(left, granularity: granularity, ignoreWhitespace: ignoreWhitespace, ignoreCase: ignoreCase)
        let rhs = pieces(right, granularity: granularity, ignoreWhitespace: ignoreWhitespace, ignoreCase: ignoreCase)
        let edits = edits(lhs, rhs)
        return (unified(edits), rows(edits))
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        let result = diff("a\nb\nc\n", "a\nx\nc\n", granularity: .line, ignoreWhitespace: false, ignoreCase: false)
        expect("diff delete", result.unified.contains("-b"))
        expect("diff insert", result.unified.contains("+x"))
        expect("diff equal", result.unified.contains(" a"))
        let folded = diff("Hello\n", "hello\n", granularity: .line, ignoreWhitespace: false, ignoreCase: true)
        expect("diff ignore case", !folded.unified.contains("-") && !folded.unified.contains("+"))
        let words = diff("one two", "one three", granularity: .word, ignoreWhitespace: false, ignoreCase: false)
        expect("diff words", words.unified.contains("-two") && words.unified.contains("+three"))
        let same = diff("", "", granularity: .character, ignoreWhitespace: false, ignoreCase: false)
        expect("diff empty", same.rows.isEmpty || same.unified.isEmpty || !same.unified.contains("-"))
    }

    private static func pieces(_ text: String, granularity: Granularity, ignoreWhitespace: Bool, ignoreCase: Bool) -> [String] {
        var source = text
        if ignoreCase { source = source.lowercased() }
        switch granularity {
        case .line:
            var lines = source.components(separatedBy: "\n")
            if lines.last == "" { lines.removeLast() }
            if ignoreWhitespace { lines = lines.map { $0.trimmingCharacters(in: .whitespaces) } }
            return lines
        case .word:
            let raw = source.split(omittingEmptySubsequences: false, whereSeparator: \.isWhitespace).map(String.init)
            return ignoreWhitespace ? raw.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } : raw
        case .character:
            let chars = source.map(String.init)
            return ignoreWhitespace ? chars.filter { $0.trimmingCharacters(in: .whitespaces).isEmpty == false } : chars
        }
    }

    private enum Op { case equal, delete, insert }

    private static func edits(_ a: [String], _ b: [String]) -> [(Op, String)] {
        if a.count * b.count > 1_500_000 {
            return a.map { (.delete, $0) } + b.map { (.insert, $0) }
        }
        let n = a.count
        let m = b.count
        var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        if n > 0 && m > 0 {
            for i in stride(from: n - 1, through: 0, by: -1) {
                for j in stride(from: m - 1, through: 0, by: -1) {
                    if a[i] == b[j] { dp[i][j] = dp[i + 1][j + 1] + 1 }
                    else { dp[i][j] = max(dp[i + 1][j], dp[i][j + 1]) }
                }
            }
        }
        var i = 0
        var j = 0
        var result: [(Op, String)] = []
        while i < n && j < m {
            if a[i] == b[j] {
                result.append((.equal, a[i]))
                i += 1
                j += 1
            } else if dp[i + 1][j] >= dp[i][j + 1] {
                result.append((.delete, a[i]))
                i += 1
            } else {
                result.append((.insert, b[j]))
                j += 1
            }
        }
        while i < n { result.append((.delete, a[i])); i += 1 }
        while j < m { result.append((.insert, b[j])); j += 1 }
        return result
    }

    private static func unified(_ edits: [(Op, String)]) -> String {
        edits.map { edit in
            switch edit.0 {
            case .equal: return " \(edit.1)"
            case .delete: return "-\(edit.1)"
            case .insert: return "+\(edit.1)"
            }
        }.joined(separator: "\n")
    }

    private static func rows(_ edits: [(Op, String)]) -> [Row] {
        var rows: [Row] = []
        var index = 0
        while index < edits.count {
            let edit = edits[index]
            switch edit.0 {
            case .equal:
                rows.append(Row(left: edit.1, right: edit.1, kind: "equal"))
                index += 1
            case .delete:
                if index + 1 < edits.count, edits[index + 1].0 == .insert {
                    rows.append(Row(left: edit.1, right: edits[index + 1].1, kind: "change"))
                    index += 2
                } else {
                    rows.append(Row(left: edit.1, right: "", kind: "delete"))
                    index += 1
                }
            case .insert:
                rows.append(Row(left: "", right: edit.1, kind: "insert"))
                index += 1
            }
        }
        return rows
    }
}
