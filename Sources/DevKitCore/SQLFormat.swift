import Foundation

public enum SQLFormat {
    public static func format(_ sql: String) -> ToolResult {
        if sql.utf8.count > 1_000_000 { return .failure("Query is larger than 1 MB.") }
        if sql.utf8.contains(0) { return .failure("Input looks like binary data.") }
        let trimmed = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .success("") }
        let tokens = tokenize(trimmed)
        let formatted = layout(tokens)
        let tables = tables(in: tokens)
        let tableText = tables.isEmpty ? "(none found)" : tables.joined(separator: "\n")
        return .success("\(formatted)\n\nTables:\n\(tableText)")
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        let result = format("select id from users join orders on orders.user_id = users.id where id = 1")
        expect("sql from", result.output.contains("\nFROM users"))
        expect("sql table", result.output.contains("users") && result.output.contains("orders"))
        expect("sql binary", format(String(repeating: "\u{0}", count: 2)).issue != nil)
    }

    private static let breakers: Set<String> = ["SELECT", "FROM", "WHERE", "GROUP BY", "ORDER BY", "HAVING", "LIMIT", "JOIN", "LEFT JOIN", "RIGHT JOIN", "INNER JOIN", "INSERT INTO", "VALUES", "UPDATE", "SET", "DELETE FROM"]

    private static func tokenize(_ sql: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var quote: Character?
        for character in sql {
            if let open = quote {
                current.append(character)
                if character == open {
                    quote = nil
                    tokens.append(current)
                    current = ""
                }
                continue
            }
            if character == "'" || character == "\"" {
                if !current.isEmpty { tokens.append(current); current = "" }
                quote = character
                current.append(character)
                continue
            }
            if character.isWhitespace || character == "," || character == "(" || character == ")" || character == ";" {
                if !current.isEmpty { tokens.append(current); current = "" }
                if !character.isWhitespace { tokens.append(String(character)) }
                continue
            }
            current.append(character)
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    private static func layout(_ tokens: [String]) -> String {
        var lines: [String] = []
        var line = ""
        var index = 0
        while index < tokens.count {
            let upper = tokens[index].uppercased()
            let phrase = index + 1 < tokens.count ? "\(upper) \(tokens[index + 1].uppercased())" : upper
            let breaker = breakers.contains(phrase) ? phrase : (breakers.contains(upper) ? upper : nil)
            if let breaker {
                if !line.isEmpty { lines.append(line) }
                let words = breaker.split(separator: " ").count
                line = breaker
                index += words
                continue
            }
            let piece = tokens[index] == "," ? "," : (line.isEmpty ? tokens[index] : " \(tokens[index])")
            line += piece == "," ? "," : piece
            index += 1
        }
        if !line.isEmpty { lines.append(line) }
        return lines.joined(separator: "\n")
    }

    private static func tables(in tokens: [String]) -> [String] {
        let markers: Set<String> = ["FROM", "JOIN", "UPDATE", "INTO"]
        var found: [String] = []
        for (index, token) in tokens.enumerated() where markers.contains(token.uppercased()) {
            let next = index + 1
            guard next < tokens.count else { continue }
            let name = tokens[next]
            let upper = name.uppercased()
            if name == "(" || name == ")" || name == "," || breakers.contains(upper) || markers.contains(upper) { continue }
            if !found.contains(name) { found.append(name) }
        }
        return found
    }
}
