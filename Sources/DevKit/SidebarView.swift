import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var model: AppModel

    private var tools: [any Tool] {
        ToolRegistry.matching(model.search)
    }

    private var selection: Binding<String> {
        Binding(
            get: { model.selectedToolID ?? "" },
            set: { model.select($0.isEmpty ? nil : $0) }
        )
    }

    var body: some View {
        List(selection: selection) {
            sidebarLabel("All Tools", symbol: "square.grid.2x2", tint: .blue)
                .tag("")

            if !favoriteTools.isEmpty {
                Section("Favorites") {
                    ForEach(favoriteTools, id: \.id) { tool in
                        toolRow(tool)
                    }
                }
            }

            ForEach(ToolCategory.allCases) { category in
                let group = tools.filter { $0.category == category }
                if !group.isEmpty {
                    Section(category.title) {
                        ForEach(group, id: \.id) { tool in
                            toolRow(tool)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $model.search, placement: .sidebar, prompt: "Search")
        .navigationTitle("DevKit")
    }

    private var favoriteTools: [any Tool] {
        model.favorites.compactMap { ToolRegistry.tool(id: $0) }.filter { tool in
            tools.contains { $0.id == tool.id }
        }
    }

    private func toolRow(_ tool: any Tool) -> some View {
        sidebarLabel(tool.name, symbol: tool.symbol, tint: tool.category.tint)
            .tag(tool.id)
            .contextMenu {
                Button(model.isFavorite(tool.id) ? "Unfavorite" : "Favorite") {
                    model.toggleFavorite(tool.id)
                }
            }
    }

    private func sidebarLabel(_ title: String, symbol: String, tint: Color) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(tint)
        }
    }
}
