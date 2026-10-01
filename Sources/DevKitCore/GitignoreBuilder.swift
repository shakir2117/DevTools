import Foundation

public enum GitignoreBuilder {
    public static func build(swift: Bool, node: Bool, python: Bool, macOS: Bool) -> String {
        var lines: [String] = []
        func add(_ block: String) {
            for line in block.split(separator: "\n", omittingEmptySubsequences: false) {
                let text = String(line)
                if text.isEmpty || text.hasPrefix("#") || !lines.contains(text) {
                    lines.append(text)
                }
            }
        }
        if swift { add(swiftBlock) }
        if node { add(nodeBlock) }
        if python { add(pythonBlock) }
        if macOS { add(macBlock) }
        while lines.last?.isEmpty == true { lines.removeLast() }
        return lines.joined(separator: "\n")
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        let text = build(swift: true, node: true, python: true, macOS: true)
        expect("ignore swift", text.contains(".build/"))
        expect("ignore node", text.contains("node_modules/"))
        expect("ignore python", text.contains("__pycache__/"))
        expect("ignore mac", text.contains(".DS_Store"))
        expect("ignore once", text.components(separatedBy: ".DS_Store").count == 2)
    }

    private static let swiftBlock = """
    # Swift
    .build/
    .swiftpm/
    Packages/
    *.xcodeproj/
    xcuserdata/
    DerivedData/
    .DS_Store
    """

    private static let nodeBlock = """
    # Node
    node_modules/
    npm-debug.log*
    .env
    dist/
    .DS_Store
    """

    private static let pythonBlock = """
    # Python
    __pycache__/
    *.py[cod]
    .venv/
    venv/
    .pytest_cache/
    .DS_Store
    """

    private static let macBlock = """
    # macOS
    .DS_Store
    .AppleDouble
    .LSOverride
    Icon?
    .Spotlight-V100
    .Trashes
    """
}
