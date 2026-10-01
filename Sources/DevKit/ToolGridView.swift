import SwiftUI

struct ToolGridView: View {
    @EnvironmentObject private var model: AppModel

    private let columns = [GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 16)]

    private var tools: [any Tool] {
        ToolRegistry.matching(model.search)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("All Tools")
                        .font(.largeTitle.weight(.semibold))
                    Text(tools.isEmpty ? "No tools match that search." : "\(tools.count) tools, grouped by what they do")
                        .foregroundStyle(.secondary)
                }
                if !tools.isEmpty {
                    ForEach(ToolCategory.allCases) { category in
                        let group = tools.filter { $0.category == category }
                        if !group.isEmpty {
                            section(category, tools: group)
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
    }

    private func card(_ tool: any Tool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: tool.symbol)
                    .font(.title2)
                    .foregroundStyle(tool.category.tint)
                    .frame(width: 32, height: 32)
                    .background(tool.category.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                Spacer()
                Image(systemName: model.isFavorite(tool.id) ? "star.fill" : "star")
                    .foregroundStyle(model.isFavorite(tool.id) ? Color.yellow : Color.secondary.opacity(0.7))
                    .onTapGesture { model.toggleFavorite(tool.id) }
            }
            Text(tool.name)
                .font(.headline)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(ToolGuide.note(for: tool.id).how)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
    }

    private func section(_ category: ToolCategory, tools: [any Tool]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(category.title)
                    .font(.title3.weight(.semibold))
                Text(category.blurb)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                ForEach(tools, id: \.id) { tool in
                    Button {
                        model.select(tool.id)
                    } label: {
                        HoverCard(cornerRadius: 16) {
                            LiveGlass(cornerRadius: 16) { card(tool) }
                        }
                    }
                    .buttonStyle(.plain)
                    .focusEffectDisabled()
                }
            }
        }
    }
}
