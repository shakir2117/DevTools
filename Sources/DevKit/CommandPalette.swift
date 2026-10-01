import SwiftUI

struct CommandPalette: View {
    @EnvironmentObject private var model: AppModel
    @State private var query = ""
    @State private var highlight = 0
    @FocusState private var focused: Bool

    private var sections: [(title: String, tools: [any Tool])] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            var result: [(String, [any Tool])] = []
            let favorites = model.favorites.compactMap { ToolRegistry.tool(id: $0) }
            let recent = model.recent.compactMap { ToolRegistry.tool(id: $0) }.filter { tool in
                !favorites.contains { $0.id == tool.id }
            }
            if !favorites.isEmpty { result.append(("Favorites", favorites)) }
            if !recent.isEmpty { result.append(("Recent", recent)) }
            if result.isEmpty { result.append(("Tools", ToolRegistry.all)) }
            return result
        }
        return [("Results", ToolRegistry.matching(query))]
    }

    private var flat: [any Tool] {
        sections.flatMap(\.tools)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture { model.paletteOpen = false }
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search tools", text: $query)
                        .textFieldStyle(.plain)
                        .focused($focused)
                        .onSubmit { openHighlighted() }
                        .onKeyPress(.upArrow) {
                            highlight = max(highlight - 1, 0)
                            return .handled
                        }
                        .onKeyPress(.downArrow) {
                            highlight = min(highlight + 1, max(flat.count - 1, 0))
                            return .handled
                        }
                        .onKeyPress(.escape) {
                            model.paletteOpen = false
                            return .handled
                        }
                }
                .padding(12)
                Divider()
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            if flat.isEmpty {
                                Text("No matching tools")
                                    .foregroundStyle(.secondary)
                                    .padding(16)
                            }
                            ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                                Text(section.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 12)
                                    .padding(.top, 10)
                                    .padding(.bottom, 4)
                                ForEach(section.tools, id: \.id) { tool in
                                    row(tool)
                                }
                            }
                        }
                        .padding(.bottom, 8)
                    }
                    .frame(maxHeight: 360)
                    .onChange(of: highlight) { _, newValue in
                        if flat.indices.contains(newValue) {
                            proxy.scrollTo(flat[newValue].id, anchor: .center)
                        }
                    }
                }
            }
            .frame(width: 520)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.08)))
            .shadow(radius: 24)
            .padding(.bottom, 80)
        }
        .onAppear { focused = true }
        .onChange(of: query) { _, _ in highlight = 0 }
        .onKeyPress(.escape) {
            model.paletteOpen = false
            return .handled
        }
        .onKeyPress(.upArrow) {
            highlight = max(highlight - 1, 0)
            return .handled
        }
        .onKeyPress(.downArrow) {
            highlight = min(highlight + 1, max(flat.count - 1, 0))
            return .handled
        }
        .onKeyPress(.return) {
            openHighlighted()
            return .handled
        }
    }

    private func row(_ tool: any Tool) -> some View {
        let index = flat.firstIndex { $0.id == tool.id } ?? 0
        return Button {
            model.select(tool.id)
            model.paletteOpen = false
        } label: {
            HStack(spacing: 10) {
                Image(systemName: tool.symbol)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(tool.name)
                    Text(tool.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(index == highlight ? Color.accentColor.opacity(0.22) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal, 6)
        }
        .buttonStyle(.plain)
        .id(tool.id)
    }

    private func openHighlighted() {
        guard flat.indices.contains(highlight) else { return }
        model.select(flat[highlight].id)
        model.paletteOpen = false
    }
}
