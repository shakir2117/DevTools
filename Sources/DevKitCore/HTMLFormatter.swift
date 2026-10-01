import Foundation
import SwiftSoup

public enum HTMLMarkup {
    public enum Mode: String, Sendable {
        case beautify, minify
    }

    public static func format(_ text: String, mode: Mode) -> ToolResult {
        if text.utf8.count > 2_000_000 { return .failure("HTML is larger than 2 MB.") }
        if let issue = InputChecks.issue(for: text, emptyPrompt: "Enter HTML to format.") {
            return .failure(issue)
        }
        do {
            let document = try parseHTML(text)
            _ = document.outputSettings().prettyPrint(pretty: mode == .beautify).indentAmount(indentAmount: 2)
            let rendered: String
            if isDocument(text) {
                rendered = try document.outerHtml()
            } else {
                rendered = try document.body()?.html() ?? ""
            }
            let output = mode == .minify ? collapseBetweenTags(rendered) : rendered
            if output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .failure("HTML did not contain any elements.")
            }
            return .success(output)
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        let pretty = format("<div><p>Hi</p></div>", mode: .beautify)
        expect("html beautify", pretty.issue == nil && pretty.output.contains("<p>") && pretty.output.contains("\n"))
        let mini = format("<div>\n  <p>Hi</p>\n</div>", mode: .minify)
        expect("html minify", mini.issue == nil && !mini.output.contains("\n") && mini.output.contains("<p>Hi</p>"))
        expect("html roundtrip text", mini.output.contains("Hi"))
        expect("html empty", format("   ", mode: .beautify).issue != nil)
        expect("html binary", format(String(repeating: "\u{0}", count: 4), mode: .minify).issue != nil)
    }

    private static func isDocument(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.hasPrefix("<!doctype") || trimmed.hasPrefix("<html")
    }

    private static func collapseBetweenTags(_ html: String) -> String {
        let sensitive: Set<String> = ["pre", "script", "style", "textarea"]
        var output = ""
        var index = html.startIndex
        var stack: [String] = []
        while index < html.endIndex {
            let character = html[index]
            if character == "<" {
                let tail = html[index...]
                if tail.hasPrefix("</") {
                    if let close = tagName(in: html, from: html.index(index, offsetBy: 2)) {
                        if let last = stack.last, last == close { stack.removeLast() }
                    }
                } else if !tail.hasPrefix("<!") && !tail.hasPrefix("<?") {
                    if let name = tagName(in: html, from: html.index(after: index)), sensitive.contains(name) {
                        stack.append(name)
                    }
                }
                output.append(character)
                index = html.index(after: index)
                continue
            }
            if character.isWhitespace, stack.isEmpty, let nextTag = nextNonSpace(html, from: index), nextTag == "<" {
                index = skipSpace(html, from: index)
                continue
            }
            output.append(character)
            index = html.index(after: index)
        }
        return output
    }

    private static func tagName(in text: String, from start: String.Index) -> String? {
        var index = start
        var name = ""
        while index < text.endIndex {
            let character = text[index]
            if character.isLetter || character.isNumber || character == "-" {
                name.append(character.lowercased())
                index = text.index(after: index)
            } else {
                break
            }
        }
        return name.isEmpty ? nil : name
    }

    private static func nextNonSpace(_ text: String, from start: String.Index) -> Character? {
        var index = start
        while index < text.endIndex {
            if !text[index].isWhitespace { return text[index] }
            index = text.index(after: index)
        }
        return nil
    }

    private static func skipSpace(_ text: String, from start: String.Index) -> String.Index {
        var index = start
        while index < text.endIndex, text[index].isWhitespace {
            index = text.index(after: index)
        }
        return index
    }
}
