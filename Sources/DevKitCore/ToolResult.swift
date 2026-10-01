import Foundation

public struct ToolIssue: Equatable, Sendable, Error {
    public var message: String
    public var line: Int?
    public var column: Int?

    public init(message: String, line: Int? = nil, column: Int? = nil) {
        self.message = message
        self.line = line
        self.column = column
    }

    public var display: String {
        if let line, let column {
            return "Line \(line), column \(column): \(message)"
        }
        if let line {
            return "Line \(line): \(message)"
        }
        return message
    }
}

public struct ToolResult: Equatable, Sendable {
    public var output: String
    public var issue: ToolIssue?

    public init(output: String, issue: ToolIssue? = nil) {
        self.output = output
        self.issue = issue
    }

    public static func success(_ output: String) -> ToolResult {
        ToolResult(output: output)
    }

    public static func failure(_ message: String, line: Int? = nil, column: Int? = nil) -> ToolResult {
        ToolResult(output: "", issue: ToolIssue(message: message, line: line, column: column))
    }

    public static func failure(_ issue: ToolIssue) -> ToolResult {
        ToolResult(output: "", issue: issue)
    }
}

public enum InputChecks {
    public static func issue(for text: String, emptyPrompt: String) -> ToolIssue? {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ToolIssue(message: emptyPrompt)
        }
        if text.utf8.contains(0) {
            return ToolIssue(message: "Input looks like binary data.")
        }
        let sample = text.prefix(8_192)
        var controls = 0
        var total = 0
        for character in sample {
            total += 1
            for scalar in character.unicodeScalars {
                if CharacterSet.controlCharacters.contains(scalar),
                   character != "\n", character != "\r", character != "\t" {
                    controls += 1
                    break
                }
            }
        }
        if total > 32, controls * 8 > total {
            return ToolIssue(message: "Input looks like binary data.")
        }
        return nil
    }

    public static func lineColumn(in text: String, utf8Offset: Int) -> (line: Int, column: Int) {
        let data = Data(text.utf8)
        let bounded = min(max(utf8Offset, 0), data.count)
        let prefix = String(decoding: data.prefix(bounded), as: UTF8.self)
        var line = 1
        var column = 1
        for character in prefix {
            if character == "\n" {
                line += 1
                column = 1
            } else {
                column += 1
            }
        }
        return (line, column)
    }
}
