import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 228, max: 280)
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 880, idealWidth: 1080, maxWidth: .infinity, minHeight: 560, idealHeight: 720, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShortcutToolbarButton(title: "All Tools", symbol: "square.grid.2x2", shortcut: "⌘[") {
                    model.select(nil)
                }
                .disabled(model.selectedToolID == nil)
            }
            ToolbarItem(placement: .primaryAction) {
                ShortcutToolbarButton(
                    title: model.selectedToolID.map { model.isFavorite($0) ? "Remove Favorite" : "Add Favorite" } ?? "Favorite",
                    symbol: model.selectedToolID.map { model.isFavorite($0) ? "star.fill" : "star" } ?? "star",
                    shortcut: "⌘D"
                ) {
                    if let id = model.selectedToolID { model.toggleFavorite(id) }
                }
                .disabled(model.selectedToolID == nil)
            }
            ToolbarItem(placement: .primaryAction) {
                ShortcutToolbarButton(title: "Copy Output", symbol: "doc.on.doc", shortcut: "⇧⌘C") {
                    model.requestCopyOutput()
                }
            }
            ToolbarItem(placement: .primaryAction) {
                ShortcutToolbarButton(title: "Command Palette", symbol: "command", shortcut: "⌘K") {
                    model.paletteOpen = true
                }
            }
        }
        .toolbarBackground(.hidden, for: .windowToolbar)
        .background {
            LiveGlassBackground().ignoresSafeArea()
            WindowFrameAutosave()
        }
        .overlay {
            if model.paletteOpen {
                CommandPalette()
            }
        }
        .overlay(alignment: .bottom) {
            if let notice = model.notice {
                Text(notice)
                    .font(.callout.weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.thickMaterial, in: Capsule())
                    .padding(.bottom, 18)
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let id = model.selectedToolID, let tool = ToolRegistry.tool(id: id) {
            VStack(spacing: 0) {
                ToolTitleBar(tool: tool)
                Divider()
                tool.makeView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .clipped()
            }
        } else {
            ToolGridView()
        }
    }
}

struct ToolTitleBar: View {
    @EnvironmentObject private var model: AppModel
    let tool: any Tool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: tool.symbol)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(tool.name)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                Text(ToolGuide.note(for: tool.id).how)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 8)
            Button("Use sample") { model.requestSample() }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .fixedSize()
            Button {
                model.toggleFavorite(tool.id)
            } label: {
                Image(systemName: model.isFavorite(tool.id) ? "star.fill" : "star")
                    .foregroundStyle(model.isFavorite(tool.id) ? Color.yellow : Color.secondary)
            }
            .buttonStyle(.borderless)
            .fixedSize()
            .help(model.isFavorite(tool.id) ? "Remove favorite" : "Add favorite")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .liveGlassBar()
    }
}

private struct ShortcutToolbarButton: View {
    var title: String
    var symbol: String
    var shortcut: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .frame(width: 16, height: 16)
                Text(shortcut)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .fixedSize()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .buttonStyle(.borderless)
        .fixedSize()
        .help("\(title) (\(shortcut))")
    }
}

private extension View {
    func liveGlassBar() -> some View {
        LiveGlass(cornerRadius: 14) { self.padding(.horizontal, 2) }
            .padding(.horizontal, 10)
            .padding(.top, 8)
    }
}
