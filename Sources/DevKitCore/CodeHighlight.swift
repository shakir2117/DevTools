import Foundation

public enum CodeHighlight {
    public enum Token: Equatable, Sendable {
        case keyword
        case string
        case number
        case comment
        case tag
        case key
        case punctuation
        case brace(Int)
    }

    public struct Span: Equatable, Sendable {
        public var location: Int
        public var length: Int
        public var token: Token
    }

    public static func spans(in text: String) -> [Span] {
        let ns = text as NSString
        let count = ns.length
        if count == 0 || count > 80_000 { return [] }
        var spans: [Span] = []
        var index = 0
        var depth = 0
        while index < count {
            let character = ns.character(at: index)
            if character == slash, index + 1 < count {
                let next = ns.character(at: index + 1)
                if next == slash {
                    let start = index
                    index += 2
                    while index < count, ns.character(at: index) != newline { index += 1 }
                    spans.append(Span(location: start, length: index - start, token: .comment))
                    continue
                }
                if next == star {
                    let start = index
                    index += 2
                    while index + 1 < count, !(ns.character(at: index) == star && ns.character(at: index + 1) == slash) {
                        index += 1
                    }
                    index = min(count, index + 2)
                    spans.append(Span(location: start, length: index - start, token: .comment))
                    continue
                }
            }
            if character == hash {
                if isHexRun(ns, from: index + 1) {
                    let start = index
                    index += 1
                    while index < count, isHex(ns.character(at: index)) { index += 1 }
                    spans.append(Span(location: start, length: index - start, token: .number))
                    continue
                }
                let start = index
                while index < count, ns.character(at: index) != newline { index += 1 }
                spans.append(Span(location: start, length: index - start, token: .comment))
                continue
            }
            if character == quote || character == apostrophe || character == backtick {
                let start = index
                let closer = character
                index += 1
                while index < count {
                    let current = ns.character(at: index)
                    if current == backslash, index + 1 < count {
                        index += 2
                        continue
                    }
                    index += 1
                    if current == closer || current == newline { break }
                }
                var token = Token.string
                if closer == quote, nextNonSpace(ns, from: index) == colon { token = .key }
                spans.append(Span(location: start, length: index - start, token: token))
                continue
            }
            if character == lessThan, index + 1 < count {
                let next = ns.character(at: index + 1)
                if isIdent(next) || next == slash {
                    let start = index
                    index += 1
                    if ns.character(at: index) == slash { index += 1 }
                    let nameStart = index
                    while index < count, isIdent(ns.character(at: index)) || isDigit(ns.character(at: index)) || ns.character(at: index) == dash {
                        index += 1
                    }
                    if index > nameStart {
                        spans.append(Span(location: start, length: index - start, token: .tag))
                        continue
                    }
                    index = start
                }
            }
            if isDigit(character) || (character == minus && index + 1 < count && isDigit(ns.character(at: index + 1))) {
                let start = index
                if character == minus { index += 1 }
                if index + 1 < count, ns.character(at: index) == zero, ns.character(at: index + 1) == letterX {
                    index += 2
                    while index < count, isHex(ns.character(at: index)) { index += 1 }
                } else {
                    while index < count, isDigit(ns.character(at: index)) { index += 1 }
                    if index < count, ns.character(at: index) == dot {
                        index += 1
                        while index < count, isDigit(ns.character(at: index)) { index += 1 }
                    }
                }
                spans.append(Span(location: start, length: index - start, token: .number))
                continue
            }
            if isIdent(character) {
                let start = index
                index += 1
                while index < count {
                    let current = ns.character(at: index)
                    if isIdent(current) || isDigit(current) { index += 1 } else { break }
                }
                let word = ns.substring(with: NSRange(location: start, length: index - start))
                if keywords.contains(word) {
                    spans.append(Span(location: start, length: index - start, token: .keyword))
                }
                continue
            }
            if braces.contains(character) {
                if character == openBrace || character == openBracket || character == openParen { depth += 1 }
                let level = max(depth, 1)
                if character == closeBrace || character == closeBracket || character == closeParen { depth = max(0, depth - 1) }
                spans.append(Span(location: index, length: 1, token: .brace(level)))
                index += 1
                continue
            }
            if punctuation.contains(character) {
                spans.append(Span(location: index, length: 1, token: .punctuation))
                index += 1
                continue
            }
            index += 1
        }
        return spans
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        let script = spans(in: "const value = 1; // note")
        expect("highlight keyword", script.contains { $0.token == .keyword && $0.length == 5 })
        expect("highlight number", script.contains { $0.token == .number })
        expect("highlight comment", script.contains { $0.token == .comment })
        let json = spans(in: "{\"name\": \"Ada\"}")
        expect("highlight key", json.contains { $0.token == .key })
        expect("highlight string", json.contains { $0.token == .string })
        let markup = spans(in: "<p>Hi</p>")
        expect("highlight tag", markup.contains { $0.token == .tag })
        expect("highlight empty", spans(in: "").isEmpty)
    }

    private static let keywords: Set<String> = [
        "const", "let", "var", "function", "return", "if", "else", "for", "while", "class", "import", "export",
        "from", "true", "false", "null", "nil", "func", "public", "private", "struct", "enum", "switch", "case",
        "break", "continue", "new", "this", "async", "await", "def", "and", "or", "not", "in", "of", "type",
        "interface", "default", "try", "catch", "throw", "package", "select", "where", "with", "as", "is",
        "do", "end", "then", "elif", "lambda", "yield", "None", "True", "False", "undefined", "typeof", "void",
        "static", "extends", "implements", "protocol", "associatedtype", "guard", "defer", "throws", "some",
        "any", "self", "Self", "super", "init", "required", "override", "internal", "fileprivate", "open",
    ]

    private static let slash = UInt16(UnicodeScalar("/").value)
    private static let star = UInt16(UnicodeScalar("*").value)
    private static let hash = UInt16(UnicodeScalar("#").value)
    private static let quote = UInt16(UnicodeScalar("\"").value)
    private static let apostrophe = UInt16(UnicodeScalar("'").value)
    private static let backtick = UInt16(UnicodeScalar("`").value)
    private static let newline = UInt16(UnicodeScalar("\n").value)
    private static let colon = UInt16(UnicodeScalar(":").value)
    private static let lessThan = UInt16(UnicodeScalar("<").value)
    private static let backslash = UInt16(UnicodeScalar("\\").value)
    private static let minus = UInt16(UnicodeScalar("-").value)
    private static let dot = UInt16(UnicodeScalar(".").value)
    private static let zero = UInt16(UnicodeScalar("0").value)
    private static let letterX = UInt16(UnicodeScalar("x").value)
    private static let dash = UInt16(UnicodeScalar("-").value)
    private static let openBrace = UInt16(UnicodeScalar("{").value)
    private static let closeBrace = UInt16(UnicodeScalar("}").value)
    private static let openBracket = UInt16(UnicodeScalar("[").value)
    private static let closeBracket = UInt16(UnicodeScalar("]").value)
    private static let openParen = UInt16(UnicodeScalar("(").value)
    private static let closeParen = UInt16(UnicodeScalar(")").value)
    private static let braces: Set<UInt16> = [openBrace, closeBrace, openBracket, closeBracket, openParen, closeParen]
    private static let punctuation: Set<UInt16> = [
        UInt16(UnicodeScalar(",").value), colon, UInt16(UnicodeScalar(";").value),
        UInt16(UnicodeScalar(".").value), UInt16(UnicodeScalar("=").value),
        UInt16(UnicodeScalar("+").value), UInt16(UnicodeScalar("*").value),
        UInt16(UnicodeScalar("%").value), UInt16(UnicodeScalar("!").value),
        UInt16(UnicodeScalar("&").value), UInt16(UnicodeScalar("|").value),
        UInt16(UnicodeScalar("?").value), UInt16(UnicodeScalar(">").value),
    ]

    private static func isIdent(_ value: UInt16) -> Bool {
        (value >= 65 && value <= 90) || (value >= 97 && value <= 122) || value == 95 || value == 36
    }

    private static func isDigit(_ value: UInt16) -> Bool {
        value >= 48 && value <= 57
    }

    private static func isHex(_ value: UInt16) -> Bool {
        isDigit(value) || (value >= 65 && value <= 70) || (value >= 97 && value <= 102)
    }

    private static func isHexRun(_ text: NSString, from start: Int) -> Bool {
        var index = start
        var digits = 0
        while index < text.length, isHex(text.character(at: index)), digits < 8 {
            digits += 1
            index += 1
        }
        if digits < 3 || digits > 8 { return false }
        if index < text.length {
            let next = text.character(at: index)
            if isIdent(next) { return false }
        }
        return true
    }

    private static func nextNonSpace(_ text: NSString, from start: Int) -> UInt16? {
        var index = start
        while index < text.length {
            let character = text.character(at: index)
            if character != 32 && character != 9 && character != 10 && character != 13 { return character }
            index += 1
        }
        return nil
    }
}
