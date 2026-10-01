import Foundation

public struct LaunchdJob: Equatable, Sendable {
    public var label: String
    public var program: String
    public var arguments: String
    public var runAtLoad: Bool
    public var startInterval: Int
    public var standardOut: String
    public var standardError: String

    public init(label: String, program: String, arguments: String, runAtLoad: Bool, startInterval: Int, standardOut: String, standardError: String) {
        self.label = label
        self.program = program
        self.arguments = arguments
        self.runAtLoad = runAtLoad
        self.startInterval = startInterval
        self.standardOut = standardOut
        self.standardError = standardError
    }
}

public enum LaunchdBuilder {
    public static func plist(_ job: LaunchdJob) -> ToolResult {
        if let issue = check(job.label, name: "Label") { return .failure(issue) }
        if job.label.hasPrefix("-") || job.label.contains(" ") { return .failure("Label should look like com.example.job.") }
        if let issue = check(job.program, name: "Program") { return .failure(issue) }
        if job.program.isEmpty { return .failure("Enter a program path.") }
        let args = job.arguments.split(whereSeparator: \.isNewline).map(String.init)
        if args.contains(where: { $0.utf8.contains(0) }) { return .failure("An argument contains a null byte.") }
        if let issue = optionalPath(job.standardOut, name: "Standard out") { return .failure(issue) }
        if let issue = optionalPath(job.standardError, name: "Standard error") { return .failure(issue) }
        if job.startInterval < 0 || job.startInterval > 86_400 * 365 { return .failure("Start interval must be from 0 to one year.") }
        var object: [String: Any] = [
            "Label": job.label,
            "ProgramArguments": [job.program] + args,
            "RunAtLoad": job.runAtLoad,
        ]
        if job.startInterval > 0 { object["StartInterval"] = job.startInterval }
        if !job.standardOut.isEmpty { object["StandardOutPath"] = job.standardOut }
        if !job.standardError.isEmpty { object["StandardErrorPath"] = job.standardError }
        guard let data = try? PropertyListSerialization.data(fromPropertyList: object, format: .xml, options: 0),
              let xml = String(data: data, encoding: .utf8) else {
            return .failure("Could not write the launchd plist.")
        }
        return .success(xml)
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        let job = LaunchdJob(label: "com.devkit.sample", program: "/bin/echo", arguments: "hello", runAtLoad: true, startInterval: 60, standardOut: "/tmp/devkit.out", standardError: "")
        let xml = plist(job)
        expect("launchd label", xml.output.contains("<string>com.devkit.sample</string>"))
        expect("launchd arg", xml.output.contains("<string>hello</string>"))
        expect("launchd interval", xml.output.contains("<integer>60</integer>"))
        expect("launchd dash", plist(LaunchdJob(label: "-bad", program: "/bin/echo", arguments: "", runAtLoad: false, startInterval: 0, standardOut: "", standardError: "")).issue != nil)
        expect("launchd break", plist(LaunchdJob(label: "com.devkit.bad\nroot", program: "/bin/echo", arguments: "", runAtLoad: false, startInterval: 0, standardOut: "", standardError: "")).issue != nil)
    }

    private static func check(_ text: String, name: String) -> ToolIssue? {
        if text.utf8.contains(0) || text.contains("\n") || text.contains("\r") {
            return ToolIssue(message: "\(name) cannot contain a line break.")
        }
        return nil
    }

    private static func optionalPath(_ text: String, name: String) -> ToolIssue? {
        if text.isEmpty { return nil }
        return check(text, name: name)
    }
}
