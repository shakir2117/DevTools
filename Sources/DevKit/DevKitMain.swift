import SwiftUI
import DevKitCore

@main
enum DevKitMain {
    static func main() {
        if let standalone = Bundle.module.url(forResource: "standalone", withExtension: "js", subdirectory: "Resources/prettier") {
            PrettierEngine.useScripts(at: standalone.deletingLastPathComponent())
        }
        if CommandLine.arguments.contains("--selftest") {
            exit(SelfTest.run())
        }
        DevKitApp.main()
    }
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
