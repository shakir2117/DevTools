import Foundation

public struct SemverVersion: Equatable, Sendable {
    public var major: Int
    public var minor: Int
    public var patch: Int
    public var prerelease: [String]
    public var build: String

    public var text: String {
        var value = "\(major).\(minor).\(patch)"
        if !prerelease.isEmpty { value += "-" + prerelease.joined(separator: ".") }
        if !build.isEmpty { value += "+" + build }
        return value
    }
}

public enum Semver {
    public enum Part: String {
        case major
        case minor
        case patch
    }

    public static func parse(_ raw: String) -> Result<SemverVersion, ToolIssue> {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty || text.contains("\n") || text.utf8.contains(0) || text.hasPrefix("-") {
            return .failure(ToolIssue(message: "Enter a version such as 1.2.3."))
        }
        let pattern = #"^v?(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?(?:\+([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$"#
        guard let match = text.range(of: pattern, options: .regularExpression) else {
            return .failure(ToolIssue(message: "\(text) is not a semantic version."))
        }
        let body = String(text[match])
        let core = body.split(separator: "+", maxSplits: 1, omittingEmptySubsequences: false)
        let build = core.count > 1 ? String(core[1]) : ""
        let head = String(core[0]).hasPrefix("v") ? String(core[0].dropFirst()) : String(core[0])
        let preParts = head.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let numbers = preParts[0].split(separator: ".")
        guard numbers.count == 3,
              let major = Int(numbers[0]),
              let minor = Int(numbers[1]),
              let patch = Int(numbers[2]) else {
            return .failure(ToolIssue(message: "\(text) is not a semantic version."))
        }
        let prerelease = preParts.count > 1 ? preParts[1].split(separator: ".").map(String.init) : []
        return .success(SemverVersion(major: major, minor: minor, patch: patch, prerelease: prerelease, build: build))
    }

    public static func compare(_ left: String, _ right: String) -> ToolResult {
        switch (parse(left), parse(right)) {
        case let (.success(a), .success(b)):
            let order = relation(a, b)
            return .success("\(a.text) \(order) \(b.text)")
        case let (.failure(issue), _), let (_, .failure(issue)):
            return .failure(issue)
        }
    }

    public static func bump(_ text: String, part: Part) -> ToolResult {
        switch parse(text) {
        case let .failure(issue):
            return .failure(issue)
        case let .success(version):
            var next = version
            next.prerelease = []
            next.build = ""
            switch part {
            case .major:
                next.major += 1
                next.minor = 0
                next.patch = 0
            case .minor:
                next.minor += 1
                next.patch = 0
            case .patch:
                next.patch += 1
            }
            return .success(next.text)
        }
    }

    public static func satisfies(_ version: String, range: String) -> ToolResult {
        switch parse(version) {
        case let .failure(issue):
            return .failure(issue)
        case let .success(value):
            switch matches(value, range: range) {
            case let .failure(issue):
                return .failure(issue)
            case let .success(allowed):
                return .success("\(value.text) \(allowed ? "satisfies" : "does not satisfy") \(range.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        }
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        expect("semver order", compare("1.2.3", "1.2.4").output.contains("<"))
        expect("semver pre", compare("1.0.0-alpha", "1.0.0").output.contains("<"))
        expect("semver bump", bump("1.2.3", part: .minor).output == "1.3.0")
        expect("semver caret", satisfies("1.9.0", range: "^1.2.3").output == "1.9.0 satisfies ^1.2.3")
        expect("semver caret major", satisfies("2.0.0", range: "^1.2.3").output.contains("does not"))
        expect("semver zero", satisfies("0.2.9", range: "^0.2.3").output.contains("satisfies"))
        expect("semver zero next", satisfies("0.3.0", range: "^0.2.3").output.contains("does not"))
        expect("semver tilde", satisfies("1.2.9", range: "~1.2.3").output.contains("satisfies"))
        if case .failure = parse("-1.2.3") { expect("semver dash", true) } else { expect("semver dash", false) }
    }

    private static func relation(_ left: SemverVersion, _ right: SemverVersion) -> String {
        if left == right || sameCore(left, right) { return "==" }
        return less(left, right) ? "<" : ">"
    }

    private static func sameCore(_ left: SemverVersion, _ right: SemverVersion) -> Bool {
        left.major == right.major && left.minor == right.minor && left.patch == right.patch && left.prerelease == right.prerelease
    }

    private static func less(_ left: SemverVersion, _ right: SemverVersion) -> Bool {
        if (left.major, left.minor, left.patch) != (right.major, right.minor, right.patch) {
            return (left.major, left.minor, left.patch) < (right.major, right.minor, right.patch)
        }
        if left.prerelease.isEmpty { return false }
        if right.prerelease.isEmpty { return true }
        let count = min(left.prerelease.count, right.prerelease.count)
        for index in 0..<count {
            let a = left.prerelease[index]
            let b = right.prerelease[index]
            if a == b { continue }
            if let an = Int(a), let bn = Int(b) { return an < bn }
            if Int(a) != nil { return true }
            if Int(b) != nil { return false }
            return a < b
        }
        return left.prerelease.count < right.prerelease.count
    }

    private static func matches(_ version: SemverVersion, range: String) -> Result<Bool, ToolIssue> {
        let text = range.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty || text.contains("\n") { return .failure(ToolIssue(message: "Enter a range such as ^1.2.3.")) }
        let operators = [">=", "<=", "~", "^", ">", "<", "="]
        let op = operators.first { text.hasPrefix($0) } ?? ""
        let rest = String(text.dropFirst(op.count)).trimmingCharacters(in: .whitespaces)
        switch parse(rest) {
        case let .failure(issue):
            return .failure(issue)
        case let .success(bound):
            switch op {
            case "", "=": return .success(sameCore(version, bound))
            case ">": return .success(less(bound, version))
            case "<": return .success(less(version, bound))
            case ">=": return .success(sameCore(version, bound) || less(bound, version))
            case "<=": return .success(sameCore(version, bound) || less(version, bound))
            case "^": return .success(inside(version, lower: bound, upper: caretUpper(bound)))
            case "~": return .success(inside(version, lower: bound, upper: SemverVersion(major: bound.major, minor: bound.minor + 1, patch: 0, prerelease: [], build: "")))
            default: return .failure(ToolIssue(message: "That range is not supported."))
            }
        }
    }

    private static func caretUpper(_ bound: SemverVersion) -> SemverVersion {
        if bound.major > 0 { return SemverVersion(major: bound.major + 1, minor: 0, patch: 0, prerelease: [], build: "") }
        if bound.minor > 0 { return SemverVersion(major: 0, minor: bound.minor + 1, patch: 0, prerelease: [], build: "") }
        return SemverVersion(major: 0, minor: 0, patch: bound.patch + 1, prerelease: [], build: "")
    }

    private static func inside(_ version: SemverVersion, lower: SemverVersion, upper: SemverVersion) -> Bool {
        let after = sameCore(version, lower) || less(lower, version)
        return after && less(version, upper)
    }
}
