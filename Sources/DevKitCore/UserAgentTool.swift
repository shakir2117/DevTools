import Foundation
import Security

public enum UserAgentToolCore {
    public enum Browser: String, CaseIterable, Sendable {
        case safari, chrome, firefox, edge
        public var title: String { rawValue.capitalized }
    }

    public enum Platform: String, CaseIterable, Sendable {
        case macOS, windows, iOS, android, linux
        public var title: String {
            switch self {
            case .macOS: return "macOS"
            case .windows: return "Windows"
            case .iOS: return "iOS"
            case .android: return "Android"
            case .linux: return "Linux"
            }
        }
    }

    public static func parse(_ text: String) -> ToolResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .failure("Paste a user agent to parse, or generate one.") }
        if trimmed.count > 8_000 { return .failure("That string is too long to be a user agent.") }
        if trimmed.utf8.contains(0) { return .failure("Input looks like binary data.") }
        let browser = detectBrowser(trimmed)
        let os = detectOS(trimmed)
        let device = detectDevice(trimmed)
        let lines = [
            "Browser: \(browser.name)\(browser.version.map { " \($0)" } ?? "")",
            "OS: \(os.name)\(os.version.map { " \($0)" } ?? "")",
            "Device: \(device)",
            "",
            trimmed,
        ]
        return .success(lines.joined(separator: "\n"))
    }

    public static func generate(browser: Browser, platform: Platform) -> ToolResult {
        guard let bytes = randomBytes(4) else { return .failure("Could not read random bytes.") }
        let major = 118 + Int(bytes[0] % 12)
        let minor = Int(bytes[1] % 6)
        let text: String
        switch (browser, platform) {
        case (.chrome, .macOS):
            text = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/\(major).0.\(6000 + Int(bytes[2])).\(Int(bytes[3])) Safari/537.36"
        case (.chrome, .windows):
            text = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/\(major).0.\(6000 + Int(bytes[2])).\(Int(bytes[3])) Safari/537.36"
        case (.chrome, .linux):
            text = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/\(major).0.\(6000 + Int(bytes[2])).\(Int(bytes[3])) Safari/537.36"
        case (.chrome, .android):
            text = "Mozilla/5.0 (Linux; Android \(13 + Int(bytes[0] % 2)); Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/\(major).0.\(6000 + Int(bytes[2])).\(Int(bytes[3])) Mobile Safari/537.36"
        case (.chrome, .iOS):
            text = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_\(minor) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/\(major).0.\(6000 + Int(bytes[2])).\(Int(bytes[3])) Mobile/15E148 Safari/604.1"
        case (.safari, .iOS):
            text = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_\(minor) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.\(minor) Mobile/15E148 Safari/604.1"
        case (.safari, _):
            text = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.\(minor) Safari/605.1.15"
        case (.firefox, .windows):
            text = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:\(major).0) Gecko/20100101 Firefox/\(major).0"
        case (.firefox, .linux):
            text = "Mozilla/5.0 (X11; Linux x86_64; rv:\(major).0) Gecko/20100101 Firefox/\(major).0"
        case (.firefox, .android):
            text = "Mozilla/5.0 (Android \(13 + Int(bytes[0] % 2)); Mobile; rv:\(major).0) Gecko/\(major).0 Firefox/\(major).0"
        case (.firefox, _):
            text = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:\(major).0) Gecko/20100101 Firefox/\(major).0"
        case (.edge, .windows):
            text = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/\(major).0.0.0 Safari/537.36 Edg/\(major).0.\(2000 + Int(bytes[2])).\(Int(bytes[3]))"
        case (.edge, .android):
            text = "Mozilla/5.0 (Linux; Android \(13 + Int(bytes[0] % 2)); Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/\(major).0.0.0 Mobile Safari/537.36 EdgA/\(major).0.\(2000 + Int(bytes[2])).\(Int(bytes[3]))"
        case (.edge, _):
            text = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/\(major).0.0.0 Safari/537.36 Edg/\(major).0.\(2000 + Int(bytes[2])).\(Int(bytes[3]))"
        }
        return .success(text)
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        let chrome = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        let parsed = parse(chrome)
        expect("ua chrome", parsed.output.contains("Browser: Chrome 120.0.0.0") && parsed.output.contains("OS: macOS 10.15.7"))
        let edge = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0"
        expect("ua edge not chrome", parse(edge).output.contains("Browser: Edge 120.0.0.0"))
        let generated = generate(browser: .firefox, platform: .linux)
        expect("ua generate", generated.issue == nil && generated.output.contains("Firefox/"))
        expect("ua empty", parse(" ").issue != nil)
        expect("ua binary", parse(String(repeating: "\u{0}", count: 3)).issue != nil)
        expect("ua huge", parse(String(repeating: "a", count: 9000)).issue != nil)
    }

    private static func detectBrowser(_ text: String) -> (name: String, version: String?) {
        if let version = capture(text, pattern: #"Edg(?:A|iOS)?/([0-9.]+)"#) {
            return ("Edge", version)
        }
        if let version = capture(text, pattern: #"Firefox/([0-9.]+)"#) {
            return ("Firefox", version)
        }
        if let version = capture(text, pattern: #"CriOS/([0-9.]+)"#) {
            return ("Chrome", version)
        }
        if text.contains("Chrome/"), let version = capture(text, pattern: #"Chrome/([0-9.]+)"#) {
            return ("Chrome", version)
        }
        if let version = capture(text, pattern: #"Version/([0-9.]+)"#), text.contains("Safari") {
            return ("Safari", version)
        }
        if text.contains("Safari") { return ("Safari", nil) }
        return ("Unknown", nil)
    }

    private static func detectOS(_ text: String) -> (name: String, version: String?) {
        if let version = capture(text, pattern: #"iPhone OS ([0-9_]+)"#) ?? capture(text, pattern: #"CPU OS ([0-9_]+)"#) {
            return ("iOS", version.replacingOccurrences(of: "_", with: "."))
        }
        if let version = capture(text, pattern: #"Mac OS X ([0-9_]+)"#) {
            return ("macOS", version.replacingOccurrences(of: "_", with: "."))
        }
        if text.contains("Macintosh") { return ("macOS", nil) }
        if let version = capture(text, pattern: #"Windows NT ([0-9.]+)"#) {
            return ("Windows", version)
        }
        if let version = capture(text, pattern: #"Android ([0-9.]+)"#) {
            return ("Android", version)
        }
        if text.contains("Linux") { return ("Linux", nil) }
        return ("Unknown", nil)
    }

    private static func detectDevice(_ text: String) -> String {
        if text.contains("iPhone") { return "iPhone" }
        if text.contains("iPad") { return "iPad" }
        if text.contains("Pixel") { return "Pixel" }
        if text.contains("Android") { return "Android" }
        if text.contains("Macintosh") { return "Macintosh" }
        if text.contains("Windows") { return "PC" }
        if text.contains("Linux") { return "PC" }
        return "Unknown"
    }

    private static func capture(_ text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1,
              let hit = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[hit])
    }

    private static func randomBytes(_ count: Int) -> [UInt8]? {
        var bytes = [UInt8](repeating: 0, count: count)
        guard SecRandomCopyBytes(kSecRandomDefault, count, &bytes) == errSecSuccess else { return nil }
        return bytes
    }
}
