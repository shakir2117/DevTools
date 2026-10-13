import SwiftUI
import DevKitCore

@main
enum DevKitMain {
    static func main() {
        if let scripts = prettierScripts() {
            PrettierEngine.useScripts(at: scripts)
        }
        if CommandLine.arguments.contains("--selftest") {
            exit(SelfTest.run())
        }
        DevKitApp.main()
    }
}

private func prettierScripts() -> URL? {
    let fileManager = FileManager.default
    let bundle = Bundle.main
    var candidates: [URL] = []
    if let resources = bundle.resourceURL {
        candidates.append(resources.appendingPathComponent("prettier"))
    }
    candidates.append(bundle.bundleURL.appendingPathComponent("DevKit_DevKit.bundle/Resources/prettier"))
    candidates.append(bundle.bundleURL.appendingPathComponent("Contents/Resources/prettier"))
    for candidate in candidates {
        if fileManager.fileExists(atPath: candidate.appendingPathComponent("standalone.js").path) {
            return candidate
        }
    }
    return nil
}

struct DevKitApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("DevKit", id: "main") {
            ContentView()
                .environmentObject(model)
        }
        .defaultSize(width: 1120, height: 740)
        .commands {
            CommandGroup(after: .sidebar) {
                Button("Command Palette") {
                    model.paletteOpen = true
                }
                .keyboardShortcut("k", modifiers: .command)
                Button("All Tools") {
                    model.select(nil)
                }
                .keyboardShortcut("[", modifiers: .command)
                .disabled(model.selectedToolID == nil)
                Button("Toggle Favorite") {
                    if let id = model.selectedToolID { model.toggleFavorite(id) }
                }
                .keyboardShortcut("d", modifiers: .command)
                .disabled(model.selectedToolID == nil)
                Button("Copy Output") {
                    model.requestCopyOutput()
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
            }
        }

        MenuBarExtra {
            MenuBarPanel()
                .environmentObject(model)
        } label: {
            Image(nsImage: MenuBarMark.image)
                .renderingMode(.template)
                .accessibilityLabel("DevKit")
        }
        .menuBarExtraStyle(.window)
    }
}
