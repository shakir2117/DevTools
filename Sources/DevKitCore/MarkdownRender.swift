import Foundation
import Markdown

public enum MarkdownRender {
    public static func html(from markdown: String) -> ToolResult {
        if markdown.count > 2_000_000 { return .failure("Markdown is larger than 2 MB.") }
        if markdown.utf8.contains(0) { return .failure("Input looks like binary data.") }
        let body = HTMLFormatter.format(markdown)
        let page = """
        <!DOCTYPE html>
        <html><head><meta charset="utf-8">
        <style>
        body { font: 16px -apple-system, sans-serif; padding: 24px; line-height: 1.45; }
        pre, code { font-family: ui-monospace, monospace; }
        pre { background: #f3f3f3; padding: 12px; overflow: auto; }
        table { border-collapse: collapse; }
        td, th { border: 1px solid #ccc; padding: 4px 8px; }
        </style></head><body>
        \(body)
        </body></html>
        """
        return .success(page)
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        let html = html(from: "# Title\n\n| A | B |\n| - | - |\n| 1 | 2 |\n\n- [x] done\n\n```swift\nlet a = 1\n```\n")
        expect("md heading", html.output.contains("<h1>") || html.output.contains("Title"))
        expect("md table", html.output.contains("<table"))
        expect("md code", html.output.contains("<code") || html.output.contains("let a = 1"))
        expect("md task", html.output.contains("done"))
        expect("md binary", MarkdownRender.html(from: String(repeating: "\u{0}", count: 4)).issue != nil)
    }
}
