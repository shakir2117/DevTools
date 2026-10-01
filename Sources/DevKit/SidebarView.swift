import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var model: AppModel

    private var tools: [any Tool] {
        ToolRegistry.matching(model.search)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search tools", text: $model.search)
                    .textFieldStyle(.plain)
                if !model.search.isEmpty {
                    Button {
                        model.search = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(8)
            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 6)

            List {
                Button {
                    model.select(nil)
                } label: {
                    Label("All Tools", systemImage: "square.grid.2x2")
                }
                .buttonStyle(.plain)
                .listRowBackground(model.selectedToolID == nil ? Color.accentColor.opacity(0.18) : Color.clear)

                if !model.favorites.isEmpty {
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
        }
        .navigationTitle("DevKit")
    }

    private var favoriteTools: [any Tool] {
        model.favorites.compactMap { ToolRegistry.tool(id: $0) }.filter { tool in
            tools.contains { $0.id == tool.id }
        }
    }

    private func toolRow(_ tool: any Tool) -> some View {
        Button {
            model.select(tool.id)
        } label: {
            Label(tool.name, systemImage: tool.symbol)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(model.isFavorite(tool.id) ? "Unfavorite" : "Favorite") {
                model.toggleFavorite(tool.id)
            }
        }
        .listRowBackground(model.selectedToolID == tool.id ? Color.accentColor.opacity(0.18) : Color.clear)
    }
}
