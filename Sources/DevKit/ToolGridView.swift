import SwiftUI

struct ToolGridView: View {
    @EnvironmentObject private var model: AppModel

    private let columns = [GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 12)]

    private var tools: [any Tool] {
        ToolRegistry.matching(model.search)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("All Tools")
                        .font(.largeTitle.weight(.semibold))
                    Text(tools.isEmpty ? "No tools match that search." : "\(tools.count) tools")
                        .foregroundStyle(.secondary)
                }
                LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                    ForEach(tools, id: \.id) { tool in
                        Button {
                            model.select(tool.id)
                        } label: {
                            card(tool)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func card(_ tool: any Tool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: tool.symbol)
                    .font(.title2)
                    .frame(width: 32, height: 32)
                    .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                Spacer()
                Image(systemName: model.isFavorite(tool.id) ? "star.fill" : "star")
                    .foregroundStyle(model.isFavorite(tool.id) ? Color.yellow : Color.secondary.opacity(0.7))
                    .onTapGesture { model.toggleFavorite(tool.id) }
            }
            Text(tool.name)
                .font(.headline)
            Text(tool.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.06))
        )
    }
}
