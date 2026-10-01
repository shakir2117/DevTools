import SwiftUI
import DevKitCore

struct UserAgentTool: Tool {
    let id = "user-agent"
    let name = "User Agent"
    let summary = "Generate a realistic user agent or parse one"
    let symbol = "desktopcomputer"
    let category = ToolCategory.generators
    func makeView() -> AnyView { AnyView(UserAgentToolView()) }
}

struct UserAgentToolView: View {
    @EnvironmentObject private var model: AppModel
    @State private var browser: UserAgentToolCore.Browser = .chrome
    @State private var platform: UserAgentToolCore.Platform = .macOS
    @State private var pushed = ""
    @State private var restored = false

    var body: some View {
        TextToolView(
            toolID: "user-agent",
            sample: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            runToken: "parse",
            canSwap: false,
            pushedInput: pushed,
            transform: { UserAgentToolCore.parse($0) }
        ) {
            HStack(spacing: 12) {
                Picker("Browser", selection: $browser) {
                    ForEach(UserAgentToolCore.Browser.allCases, id: \.self) { item in
                        Text(item.title).tag(item)
                    }
                }
                .frame(maxWidth: 140)
                Picker("Platform", selection: $platform) {
                    ForEach(UserAgentToolCore.Platform.allCases, id: \.self) { item in
                        Text(item.title).tag(item)
                    }
                }
                .frame(maxWidth: 140)
                Button("Generate") { generate() }
                Spacer()
            }
        }
        .onAppear(perform: restore)
        .onChange(of: browser) { _, _ in persist() }
        .onChange(of: platform) { _, _ in persist() }
    }

    private func generate() {
        let result = UserAgentToolCore.generate(browser: browser, platform: platform)
        if result.issue == nil {
            pushed = result.output
        }
    }

    private func restore() {
        guard !restored else { return }
        restored = true
        let object = model.loadOptionsObject(for: "user-agent")
        if let value = object["browser"] as? String, let parsed = UserAgentToolCore.Browser(rawValue: value) { browser = parsed }
        if let value = object["platform"] as? String, let parsed = UserAgentToolCore.Platform(rawValue: value) { platform = parsed }
    }

    private func persist() {
        model.saveOptionsObject(["browser": browser.rawValue, "platform": platform.rawValue], for: "user-agent")
    }
}
