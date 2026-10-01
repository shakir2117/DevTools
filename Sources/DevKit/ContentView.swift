import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            detail
        }
        .navigationSplitViewColumnWidth(min: 210, ideal: 236, max: 320)
        .frame(minWidth: 960, minHeight: 600)
        .background(WindowFrameAutosave())
        .overlay {
            if model.paletteOpen {
                CommandPalette()
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
            VStack(alignment: .leading, spacing: 1) {
                Text(tool.name)
                    .font(.title3.weight(.semibold))
                Text(tool.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                model.toggleFavorite(tool.id)
            } label: {
                Image(systemName: model.isFavorite(tool.id) ? "star.fill" : "star")
                    .foregroundStyle(model.isFavorite(tool.id) ? Color.yellow : Color.secondary)
            }
            .buttonStyle(.borderless)
            .help(model.isFavorite(tool.id) ? "Remove favorite" : "Add favorite")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
