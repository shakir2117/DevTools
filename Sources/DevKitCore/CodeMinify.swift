import Foundation

public enum CodeMinify {
    public enum Language: String, CaseIterable, Sendable {
        case json, xml, javascript, css

        public var title: String {
            switch self {
            case .json: return "JSON"
            case .xml: return "XML"
            case .javascript: return "JavaScript"
            case .css: return "CSS"
            }
        }
    }

    public static func minify(_ text: String, language: Language) -> ToolResult {
        if text.utf8.count > 2_000_000 { return .failure("Input is larger than 2 MB.") }
        if let issue = InputChecks.issue(for: text, emptyPrompt: "Enter code to minify.") {
            return .failure(issue)
        }
        switch language {
        case .json:
            return JSONFormatter.format(text, mode: .minify, indent: .two, sortKeys: false)
        case .xml:
            return XMLFormatter.format(text, mode: .minify)
        case .javascript:
            return .success(squeezeScript(text))
        case .css:
            return .success(squeezeStyle(text))
        }
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        let json = minify("{\n  \"a\": 1\n}", language: .json)
        expect("minify json", json.output == "{\"a\":1}" && json.issue == nil)
        let xml = minify("<root>\n  <a>1</a>\n</root>", language: .xml)
        expect("minify xml", xml.issue == nil && !xml.output.contains("\n  "))
        let javascript = minify("const value = 1 + 2;\n// note\n", language: .javascript)
        expect("minify js", javascript.output == "const value=1+2;" && javascript.issue == nil)
        let css = minify(".a {\n  color: red;\n}\n", language: .css)
        expect("minify css", css.output == ".a{color:red}" && css.issue == nil)
        let quoted = minify("const label = \"a + b\";", language: .javascript)
        expect("minify js string", quoted.output.contains("\"a + b\""))
        expect("minify empty", minify("  ", language: .javascript).issue != nil)
        expect("minify bad json", minify("{", language: .json).issue != nil)
    }

    private static let regexWords: Set<String> = [
        "return", "throw", "case", "typeof", "void", "delete", "do", "else", "in", "of",
        "yield", "await", "instanceof", "new", "typeof",
    ]

    private static func squeezeScript(_ text: String) -> String {
        var output = ""
        var index = text.startIndex
        var previousWord = false
        var previousToken = ""
        func emit(_ token: String, word: Bool) {
            if previousWord && word { output.append(" ") }
            output.append(token)
            previousWord = word
            previousToken = token
        }
        while index < text.endIndex {
            let character = text[index]
            if character.isWhitespace {
                index = text.index(after: index)
                continue
            }
            if character == "/" {
                let next = peek(text, index)
                if next == "/" {
                    index = skipLineComment(text, from: text.index(index, offsetBy: 2))
                    continue
                }
                if next == "*" {
                    index = skipBlockComment(text, from: text.index(index, offsetBy: 2))
                    continue
                }
                if startsRegex(previousToken) {
                    let token = readRegex(text, from: index)
                    emit(token.text, word: false)
                    index = token.end
                    continue
                }
            }
            if character == "'" || character == "\"" || character == "`" {
                let token = readQuoted(text, from: index, quote: character)
                emit(token.text, word: false)
                index = token.end
                continue
            }
            if isWord(character) {
                let token = readWhile(text, from: index, isWord)
                emit(token.text, word: true)
                index = token.end
                continue
            }
            emit(String(character), word: false)
            index = text.index(after: index)
        }
        return output
    }

    private static func squeezeStyle(_ text: String) -> String {
        var output = ""
        var index = text.startIndex
        var pendingSpace = false
        while index < text.endIndex {
            let character = text[index]
            if character == "/" && peek(text, index) == "*" {
                index = skipBlockComment(text, from: text.index(index, offsetBy: 2))
                continue
            }
            if character == "'" || character == "\"" {
                if pendingSpace, let last = output.last, isWord(last) {
                    output.append(" ")
                }
                let token = readQuoted(text, from: index, quote: character)
                output.append(token.text)
                pendingSpace = false
                index = token.end
                continue
            }
            if character.isWhitespace {
                pendingSpace = !output.isEmpty
                index = text.index(after: index)
                continue
            }
            if pendingSpace, let last = output.last, isWord(last), isWord(character) {
                output.append(" ")
            }
            output.append(character)
            pendingSpace = false
            index = text.index(after: index)
        }
        return output.replacingOccurrences(of: ";}", with: "}")
    }

    private static func startsRegex(_ previous: String) -> Bool {
        if previous.isEmpty { return true }
        if previous == ")" || previous == "]" { return false }
        if let first = previous.first, isWord(first), !regexWords.contains(previous) { return false }
        return true
    }

    private static func readRegex(_ text: String, from start: String.Index) -> (text: String, end: String.Index) {
        var index = text.index(after: start)
        var escaped = false
        var inClass = false
        while index < text.endIndex {
            let character = text[index]
            if escaped {
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else if character == "[" {
                inClass = true
            } else if character == "]" {
                inClass = false
            } else if character == "/" && !inClass {
                index = text.index(after: index)
                while index < text.endIndex, text[index].isLetter {
                    index = text.index(after: index)
                }
                return (String(text[start..<index]), index)
            } else if character == "\n" {
                break
            }
            index = text.index(after: index)
        }
        return ("/", text.index(after: start))
    }

    private static func readQuoted(_ text: String, from start: String.Index, quote: Character) -> (text: String, end: String.Index) {
        var index = text.index(after: start)
        var escaped = false
        while index < text.endIndex {
            let character = text[index]
            if escaped {
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else if character == quote {
                index = text.index(after: index)
                return (String(text[start..<index]), index)
            }
            index = text.index(after: index)
        }
        return (String(text[start..<index]), index)
    }

    private static func readWhile(_ text: String, from start: String.Index, _ predicate: (Character) -> Bool) -> (text: String, end: String.Index) {
        var index = start
        while index < text.endIndex, predicate(text[index]) {
            index = text.index(after: index)
        }
        return (String(text[start..<index]), index)
    }

    private static func skipLineComment(_ text: String, from start: String.Index) -> String.Index {
        var index = start
        while index < text.endIndex, text[index] != "\n" {
            index = text.index(after: index)
        }
        return index
    }

    private static func skipBlockComment(_ text: String, from start: String.Index) -> String.Index {
        var index = start
        while index < text.endIndex {
            if text[index] == "*" && peek(text, index) == "/" {
                return text.index(index, offsetBy: 2, limitedBy: text.endIndex) ?? text.endIndex
            }
            index = text.index(after: index)
        }
        return text.endIndex
    }

    private static func peek(_ text: String, _ index: String.Index) -> Character? {
        let next = text.index(after: index)
        guard next < text.endIndex else { return nil }
        return text[next]
    }

    private static func isWord(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_" || character == "$"
    }
}
