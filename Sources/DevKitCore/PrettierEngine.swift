import Foundation
import JavaScriptCore

public enum PrettierEngine {
    public enum Language: String, CaseIterable, Sendable {
        case javascript, css, scss, less

        public var title: String {
            switch self {
            case .javascript: return "JavaScript"
            case .css: return "CSS"
            case .scss: return "SCSS"
            case .less: return "LESS"
            }
        }

        var parser: String {
            switch self {
            case .javascript: return "babel"
            case .css: return "css"
            case .scss: return "scss"
            case .less: return "less"
            }
        }

        var plugins: String {
            switch self {
            case .javascript: return "[prettierPlugins.babel, prettierPlugins.estree]"
            case .css, .scss, .less: return "[prettierPlugins.postcss]"
            }
        }
    }

    public static func useScripts(at directory: URL) {
        gate.sync {
            if scriptsDirectory?.path != directory.path {
                scriptsDirectory = directory
                context = nil
            }
        }
    }

    public static func format(_ text: String, language: Language, tabWidth: Int, useTabs: Bool) -> ToolResult {
        if text.utf8.count > 1_000_000 { return .failure("Input is larger than 1 MB.") }
        if let issue = InputChecks.issue(for: text, emptyPrompt: "Enter code to format.") {
            return .failure(issue)
        }
        return gate.sync {
            do {
                let js = try contextOrLoad()
                js.setObject(text, forKeyedSubscript: "__devkitSource" as NSString)
                let width = max(1, min(tabWidth, 8))
                let script = """
                var __devkitResult = null;
                var __devkitError = null;
                prettier.format(__devkitSource, {
                  parser: "\(language.parser)",
                  plugins: \(language.plugins),
                  tabWidth: \(width),
                  useTabs: \(useTabs ? "true" : "false")
                }).then(function(value) {
                  __devkitResult = value;
                }, function(error) {
                  __devkitError = error && error.message ? String(error.message) : String(error);
                });
                """
                js.evaluateScript(script)
                if let exception = lastException {
                    lastException = nil
                    return .failure(exception)
                }
                let failure = js.objectForKeyedSubscript("__devkitError")
                if let failure, !failure.isNull, !failure.isUndefined {
                    let message = failure.toString() ?? "Prettier failed."
                    return .failure(message.isEmpty ? "Prettier failed." : message)
                }
                let formatted = js.objectForKeyedSubscript("__devkitResult")
                guard let formatted, !formatted.isNull, !formatted.isUndefined, let output = formatted.toString() else {
                    return .failure("Prettier did not return formatted code.")
                }
                return .success(output)
            } catch {
                return .failure(error.localizedDescription)
            }
        }
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        let javascript = format("const x=1", language: .javascript, tabWidth: 2, useTabs: false)
        expect("prettier js", javascript.issue == nil && javascript.output.contains("const x = 1;"))
        let css = format("a{color:red}", language: .css, tabWidth: 2, useTabs: false)
        expect("prettier css", css.issue == nil && css.output.contains("color: red"))
        let scss = format("$n:1;a{width:$n}", language: .scss, tabWidth: 2, useTabs: false)
        expect("prettier scss", scss.issue == nil && scss.output.contains("$n"))
        let less = format("@n:1;a{width:@n}", language: .less, tabWidth: 2, useTabs: false)
        expect("prettier less", less.issue == nil && less.output.contains("@n"))
        expect("prettier empty", format("  ", language: .javascript, tabWidth: 2, useTabs: false).issue != nil)
        expect("prettier bad js", format("const =", language: .javascript, tabWidth: 2, useTabs: false).issue != nil)
    }

    private static let gate = DispatchQueue(label: "devkit.prettier")
    private static var scriptsDirectory: URL?
    private static var context: JSContext?
    private static var lastException: String?

    private static func contextOrLoad() throws -> JSContext {
        if let context { return context }
        guard let directory = scriptsDirectory else {
            throw ToolIssue(message: "Prettier scripts are not in the app bundle.")
        }
        guard let js = JSContext() else {
            throw ToolIssue(message: "JavaScriptCore could not start.")
        }
        js.exceptionHandler = { _, value in
            lastException = value?.toString() ?? "JavaScript failed."
        }
        for name in ["standalone.js", "babel.js", "estree.js", "postcss.js", "html.js"] {
            let url = directory.appendingPathComponent(name)
            let source = try String(contentsOf: url, encoding: .utf8)
            js.evaluateScript(source, withSourceURL: url)
            if let exception = lastException {
                lastException = nil
                throw ToolIssue(message: "Could not load \(name): \(exception)")
            }
        }
        context = js
        return js
    }
}
