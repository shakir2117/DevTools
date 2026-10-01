import SwiftUI
import AppKit

struct LiveGlassBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
    }
}

struct HoverCard<Content: View>: View {
    var cornerRadius: CGFloat = 16
    @ViewBuilder var content: () -> Content
    @State private var hovering = false

    var body: some View {
        content()
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(hovering ? 0.2 : 0), lineWidth: 1)
            }
            .shadow(color: .black.opacity(hovering ? 0.2 : 0), radius: hovering ? 12 : 0, y: hovering ? 5 : 0)
            .scaleEffect(hovering ? 1.02 : 1)
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.14), value: hovering)
    }
}

struct FlowRow: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let limit = proposal.width ?? .greatestFiniteMagnitude
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var used: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + spacing + size.width > limit {
                y += rowHeight + lineSpacing
                x = 0
                rowHeight = 0
            }
            if x > 0 { x += spacing }
            x += size.width
            rowHeight = max(rowHeight, size.height)
            used = max(used, x)
        }
        let width = proposal.width.map { $0.isFinite ? $0 : used } ?? used
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + spacing + size.width > bounds.maxX + 0.5 {
                y += rowHeight + lineSpacing
                x = bounds.minX
                rowHeight = 0
            }
            if x > bounds.minX { x += spacing }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(width: size.width, height: size.height))
            x += size.width
            rowHeight = max(rowHeight, size.height)
        }
    }
}

extension View {
    func toolPage() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(16)
    }
}

struct LiveGlass<Content: View>: View {
    var cornerRadius: CGFloat = 16
    @ViewBuilder var content: () -> Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        glassBody(shape)
    }

    @ViewBuilder
    private func glassBody(_ shape: RoundedRectangle) -> some View {
        if #available(macOS 26, *) {
            content().glassEffect(.regular, in: shape)
        } else {
            content().background(.regularMaterial, in: shape)
        }
    }
}

struct FittedSplit<Left: View, Right: View>: View {
    @ViewBuilder var left: () -> Left
    @ViewBuilder var right: () -> Right
    @State private var ratio: CGFloat = 0.5
    @State private var dragOrigin: CGFloat?

    var body: some View {
        GeometryReader { proxy in
            let total = max(proxy.size.width, 1)
            let divider: CGFloat = 6
            let usable = max(total - divider, 1)
            let minPane = min(120, usable / 2)
            let span = max(usable - minPane * 2, 1)
            let leftWidth = minPane + span * min(max(ratio, 0), 1)
            HStack(spacing: 0) {
                left()
                    .frame(width: leftWidth, height: proxy.size.height, alignment: .topLeading)
                    .clipped()
                Color.clear
                    .frame(width: divider, height: proxy.size.height)
                    .overlay(Rectangle().fill(Color.primary.opacity(0.2)).frame(width: 1))
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                if dragOrigin == nil { dragOrigin = ratio }
                                let next = (dragOrigin ?? ratio) + value.translation.width / span
                                ratio = min(max(next, 0), 1)
                            }
                            .onEnded { _ in dragOrigin = nil }
                    )
                    .onContinuousHover { phase in
                        switch phase {
                        case .active: NSCursor.resizeLeftRight.set()
                        case .ended: NSCursor.arrow.set()
                        }
                    }
                right()
                    .frame(width: max(usable - leftWidth, minPane), height: proxy.size.height, alignment: .topLeading)
                    .clipped()
            }
            .frame(width: total, height: proxy.size.height, alignment: .leading)
            .clipped()
        }
        .clipped()
    }
}

struct GlassIconButton: View {
    var title: String
    var symbol: String
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        button
            .onHover { hovering = $0 }
            .overlay(alignment: .top) {
                if hovering {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.08))
                        )
                        .fixedSize()
                        .offset(y: -34)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .zIndex(hovering ? 2 : 0)
            .animation(.easeOut(duration: 0.12), value: hovering)
    }

    @ViewBuilder
    private var button: some View {
        if #available(macOS 26, *) {
            Button(action: action) {
                Label(title, systemImage: symbol)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glass)
            .controlSize(.large)
        } else {
            Button(action: action) {
                Label(title, systemImage: symbol)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
        }
    }
}
