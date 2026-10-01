import SwiftUI
import AppKit

enum MenuBarMark {
    static let image: NSImage = {
        let title = "</>" as NSString
        let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white,
        ]
        let textSize = title.size(withAttributes: attributes)
        let size = NSSize(width: ceil(textSize.width) + 2, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let origin = NSPoint(
                x: (rect.width - textSize.width) / 2,
                y: (rect.height - textSize.height) / 2
            )
            title.draw(at: origin, withAttributes: attributes)
            return true
        }
        image.isTemplate = true
        return image
    }()
}

struct MenuBarPanel: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Open a tool", text: $query)
                .textFieldStyle(.roundedBorder)
                .focused($searchFocused)
                .padding(10)
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        sectionTitle("Pinned")
                        if pinned.isEmpty {
                            Text("Star a tool to pin it here.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                        } else {
                            ForEach(pinned) { row in
                                toolButton(row)
                            }
                        }
                        sectionTitle("All Tools")
                    }
                    ForEach(catalog) { row in
                        toolButton(row)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(width: 320, height: 460)
        .onAppear { searchFocused = true }
    }

    private var pinned: [ToolRow] {
        model.favorites.compactMap { id in
            guard let tool = ToolRegistry.tool(id: id) else { return nil }
            return ToolRow(tool)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 2)
    }

    private func toolButton(_ row: ToolRow) -> some View {
        Button {
            open(row.id)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: row.symbol)
                    .frame(width: 18)
                    .foregroundStyle(row.tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text(row.name)
                        .lineLimit(1)
                    Text(row.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
                if model.isFavorite(row.id) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var catalog: [ToolRow] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty else { return rows }
        return rows.filter { !model.isFavorite($0.id) }
    }

    private var rows: [ToolRow] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let tools: [any Tool]
        if trimmed.isEmpty {
            tools = ToolRegistry.all
        } else {
            tools = ToolRegistry.all.compactMap { tool -> (Int, any Tool)? in
                guard let score = Fuzzy.score(query: trimmed, name: tool.name, summary: tool.summary) else { return nil }
                return (score, tool)
            }
            .sorted { $0.0 > $1.0 }
            .map(\.1)
        }
        return tools.map { ToolRow($0) }
    }

    private func open(_ id: String) {
        model.select(id)
        dismiss()
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct ToolRow: Identifiable {
    var id: String
    var name: String
    var summary: String
    var symbol: String
    var tint: Color

    init(_ tool: any Tool) {
        id = tool.id
        name = tool.name
        summary = tool.summary
        symbol = tool.symbol
        tint = tool.category.tint
    }
}
