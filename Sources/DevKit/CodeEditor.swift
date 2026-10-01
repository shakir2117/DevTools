import SwiftUI
import AppKit
import DevKitCore

struct CodePane: View {
    @Binding var text: String
    var editable: Bool = true
    var errorLine: Int? = nil
    @State private var wrap = true
    @State private var query = ""
    @State private var findTick = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .fixedSize()
                TextField("Find", text: $query)
                    .textFieldStyle(.plain)
                    .focusEffectDisabled()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.16), lineWidth: 1)
                    )
                    .frame(maxWidth: .infinity)
                    .onSubmit { findTick += 1 }
                Button("Next") { findTick += 1 }
                    .fixedSize()
                    .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Toggle("Wrap", isOn: $wrap)
                    .toggleStyle(.checkbox)
                    .fixedSize()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
            CodeEditor(
                text: $text,
                editable: editable,
                wrap: wrap,
                errorLine: errorLine,
                find: query,
                findTick: findTick
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
    }
}

struct CodeEditor: NSViewRepresentable {
    @Binding var text: String
    var editable: Bool = true
    var wrap: Bool = true
    var errorLine: Int? = nil
    var find: String = ""
    var findTick: Int = 0

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: EditorHost, context: Context) -> CGSize? {
        CGSize(width: Self.finite(proposal.width, fallback: 320), height: Self.finite(proposal.height, fallback: 180))
    }

    func makeNSView(context: Context) -> EditorHost {
        let scroll = NSTextView.scrollableTextView()
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.hasVerticalScroller = true
        scroll.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        scroll.setContentHuggingPriority(.defaultLow, for: .horizontal)
        guard let textView = scroll.documentView as? NSTextView else { return EditorHost(scrollView: scroll) }
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isEditable = editable
        textView.isSelectable = true
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.font = CodePalette.font
        textView.textContainerInset = NSSize(width: 8, height: 10)
        scroll.automaticallyAdjustsContentInsets = false
        scroll.contentInsets = NSEdgeInsets()
        textView.string = text
        let ruler = LineNumberRuler(scrollView: scroll, orientation: .verticalRuler)
        ruler.clientView = textView
        scroll.verticalRulerView = ruler
        scroll.hasVerticalRuler = true
        scroll.rulersVisible = true
        scroll.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.boundsChanged(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scroll.contentView
        )
        applyWrap(wrap, textView: textView, scroll: scroll)
        CodePalette.apply(to: textView, errorLine: errorLine)
        ruler.noteText(textView.string, errorLine: errorLine)
        return EditorHost(scrollView: scroll)
    }

    func updateNSView(_ host: EditorHost, context: Context) {
        let scroll = host.scrollView
        guard let textView = scroll.documentView as? NSTextView else { return }
        context.coordinator.text = $text
        textView.isEditable = editable
        let appearance = textView.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
        let changed = textView.string != text
        if changed {
            let selection = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = clamped(selection, length: (text as NSString).length)
        }
        let visibleWidth = Self.clipWidth(scroll)
        if context.coordinator.wrap != wrap || (wrap && abs(context.coordinator.wrappedWidth - visibleWidth) > 1) {
            context.coordinator.wrap = wrap
            context.coordinator.wrappedWidth = wrap ? visibleWidth : 0
            applyWrap(wrap, textView: textView, scroll: scroll)
        }
        let errorChanged = context.coordinator.errorLine != errorLine
        context.coordinator.errorLine = errorLine
        if changed || errorChanged || context.coordinator.appearance != appearance {
            context.coordinator.appearance = appearance
            CodePalette.apply(to: textView, errorLine: errorLine)
        }
        if context.coordinator.findTick != findTick {
            context.coordinator.findTick = findTick
            reveal(find, in: textView)
        }
        if changed || errorChanged || context.coordinator.needsPin {
            context.coordinator.needsPin = false
            showText(textView, scroll: scroll, line: errorChanged ? errorLine : nil)
        }
        (scroll.verticalRulerView as? LineNumberRuler)?.noteText(textView.string, errorLine: errorLine)
    }

    private static func finite(_ value: CGFloat?, fallback: CGFloat) -> CGFloat {
        guard let value, value.isFinite, value > 1 else { return fallback }
        return value
    }

    private static func clipWidth(_ scroll: NSScrollView) -> CGFloat {
        let width = scroll.contentView.bounds.width
        if width > 1 { return width }
        let fallback = scroll.bounds.width - (scroll.hasVerticalRuler ? scroll.verticalRulerView?.ruleThickness ?? 0 : 0)
        return max(fallback, 1)
    }

    private func applyWrap(_ wrap: Bool, textView: NSTextView, scroll: NSScrollView) {
        guard let container = textView.textContainer else { return }
        let infinite = CGFloat.greatestFiniteMagnitude
        let visibleWidth = Self.clipWidth(scroll)
        container.lineBreakMode = wrap ? .byCharWrapping : .byClipping
        if wrap {
            scroll.hasHorizontalScroller = false
            textView.isHorizontallyResizable = false
            textView.isVerticallyResizable = true
            textView.autoresizingMask = [.width]
            container.widthTracksTextView = true
            container.containerSize = NSSize(width: visibleWidth, height: infinite)
            textView.minSize = NSSize(width: 0, height: max(scroll.contentView.bounds.height, 1))
            textView.maxSize = NSSize(width: visibleWidth, height: infinite)
            var frame = textView.frame
            frame.origin = .zero
            frame.size.width = visibleWidth
            frame.size.height = max(frame.size.height, scroll.contentView.bounds.height)
            textView.frame = frame
        } else {
            scroll.hasHorizontalScroller = true
            textView.isHorizontallyResizable = true
            textView.isVerticallyResizable = true
            textView.autoresizingMask = [.width, .height]
            container.widthTracksTextView = false
            container.containerSize = NSSize(width: infinite, height: infinite)
            textView.minSize = NSSize(width: visibleWidth, height: max(scroll.contentView.bounds.height, 1))
            textView.maxSize = NSSize(width: infinite, height: infinite)
            var frame = textView.frame
            frame.origin = .zero
            frame.size.height = max(frame.size.height, scroll.contentView.bounds.height)
            textView.frame = frame
        }
        let length = textView.textStorage?.length ?? 0
        textView.layoutManager?.invalidateLayout(
            forCharacterRange: NSRange(location: 0, length: length),
            actualCharacterRange: nil
        )
        textView.needsDisplay = true
        scroll.verticalRulerView?.needsDisplay = true
    }

    private func clamped(_ selection: [NSValue], length: Int) -> [NSValue] {
        selection.compactMap { value in
            let range = value.rangeValue
            guard range.location <= length else { return nil }
            let end = min(NSMaxRange(range), length)
            return NSValue(range: NSRange(location: range.location, length: end - range.location))
        }
    }

    private func reveal(_ query: String, in textView: NSTextView) {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = textView.string as NSString
        guard !needle.isEmpty, source.length > 0 else { return }
        let selected = textView.selectedRange()
        var start = NSMaxRange(selected)
        if start > source.length { start = 0 }
        var found = source.range(
            of: needle,
            options: [.caseInsensitive],
            range: NSRange(location: start, length: source.length - start)
        )
        if found.location == NSNotFound, start > 0 {
            found = source.range(of: needle, options: [.caseInsensitive])
        }
        guard found.location != NSNotFound else { return }
        textView.setSelectedRange(found)
        textView.scrollRangeToVisible(found)
        textView.showFindIndicator(for: found)
    }

    private func showText(_ textView: NSTextView, scroll: NSScrollView, line: Int?) {
        guard let layout = textView.layoutManager, let container = textView.textContainer else { return }
        layout.ensureLayout(for: container)
        let used = layout.usedRect(for: container).height + textView.textContainerInset.height * 2
        let clip = scroll.contentView.bounds
        if used <= clip.height + 1 {
            scroll.contentView.scroll(to: .zero)
            scroll.reflectScrolledClipView(scroll.contentView)
            return
        }
        guard let line else { return }
        let source = textView.string as NSString
        guard let range = CodePalette.lineRange(line, in: source) else { return }
        let location = min(range.location, max(source.length - 1, 0))
        guard layout.numberOfGlyphs > 0 else { return }
        let glyph = layout.glyphIndexForCharacter(at: location)
        var rect = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        let pad = textView.textContainerInset.height + 6
        rect.origin.x = 0
        rect.origin.y = max(0, rect.minY + textView.textContainerOrigin.y - pad)
        rect.size.width = max(clip.width, 1)
        rect.size.height += pad * 2
        textView.scrollToVisible(rect)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var appearance: NSAppearance.Name?
        var wrap = true
        var wrappedWidth: CGFloat = 0
        var errorLine: Int?
        var findTick = 0
        var needsPin = true

        init(text: Binding<String>) { self.text = text }

        deinit { NotificationCenter.default.removeObserver(self) }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView, textView.isEditable else { return }
            text.wrappedValue = textView.string
            CodePalette.apply(to: textView, errorLine: errorLine)
            (textView.enclosingScrollView?.verticalRulerView as? LineNumberRuler)?.noteText(textView.string, errorLine: errorLine)
        }

        @objc func boundsChanged(_ notification: Notification) {
            guard let clip = notification.object as? NSClipView,
                  let scroll = clip.enclosingScrollView,
                  let textView = scroll.documentView as? NSTextView else { return }
            scroll.verticalRulerView?.needsDisplay = true
            guard wrap, let container = textView.textContainer else { return }
            let width = CodeEditor.clipWidth(scroll)
            guard abs(wrappedWidth - width) > 1 else { return }
            wrappedWidth = width
            container.containerSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
            textView.maxSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
            var frame = textView.frame
            frame.size.width = width
            textView.frame = frame
        }
    }
}

final class EditorHost: NSView {
    let scrollView: NSScrollView

    init(scrollView: NSScrollView) {
        self.scrollView = scrollView
        super.init(frame: .zero)
        wantsLayer = true
        clipsToBounds = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentHuggingPriority(.defaultLow, for: .vertical)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .vertical)
    }

    required init?(coder: NSCoder) { nil }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }

    override var fittingSize: NSSize {
        NSSize(width: 120, height: 80)
    }
}

final class LineNumberRuler: NSRulerView {
    private var starts: [Int] = [0]
    private var indexed = ""
    var errorLine: Int?

    func noteText(_ string: String, errorLine: Int?) {
        self.errorLine = errorLine
        if string != indexed {
            indexed = string
            var values = [0]
            let source = string as NSString
            var index = 0
            while index < source.length {
                let range = source.lineRange(for: NSRange(location: index, length: 0))
                let next = NSMaxRange(range)
                if next <= index { break }
                if next < source.length { values.append(next) }
                index = next
            }
            starts = values
            let digits = max(2, String(values.count).count)
            let thickness = CGFloat(digits) * 8 + 14
            if abs(ruleThickness - thickness) > 0.5 { ruleThickness = thickness }
        }
        needsDisplay = true
    }

    private func lineNumber(at location: Int) -> Int {
        var low = 0
        var high = starts.count
        while low < high {
            let mid = (low + high) / 2
            if starts[mid] <= location { low = mid + 1 } else { high = mid }
        }
        return max(low, 1)
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = clientView as? NSTextView,
              let layoutManager = textView.layoutManager,
              let container = textView.textContainer else { return }
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let background = dark
            ? NSColor(srgbRed: 0.08, green: 0.08, blue: 0.09, alpha: 1)
            : NSColor(srgbRed: 0.94, green: 0.94, blue: 0.95, alpha: 1)
        background.setFill()
        bounds.fill()
        if textView.string.isEmpty {
            drawLabel(1, y: textView.textContainerOrigin.y, height: CodePalette.font.ascender + 4, dark: dark)
            return
        }
        let visible = scrollView?.contentView.bounds ?? textView.visibleRect
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visible, in: container)
        guard glyphRange.length > 0 else { return }
        let characterRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        let source = textView.string as NSString
        var index = characterRange.location
        let limit = NSMaxRange(characterRange)
        while index < source.length && index <= limit {
            let lineRange = source.lineRange(for: NSRange(location: index, length: 0))
            let glyph = layoutManager.glyphIndexForCharacter(at: lineRange.location)
            var extra = NSRange()
            let fragment = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: &extra)
            let point = convert(NSPoint(x: 0, y: fragment.minY + textView.textContainerOrigin.y), from: textView)
            drawLabel(lineNumber(at: lineRange.location), y: point.y, height: fragment.height, dark: dark)
            let next = NSMaxRange(lineRange)
            if next <= index { break }
            index = next
        }
    }

    private func drawLabel(_ line: Int, y: CGFloat, height: CGFloat, dark: Bool) {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        let color: NSColor = line == errorLine
            ? .systemRed
            : (dark ? NSColor(srgbRed: 0.55, green: 0.55, blue: 0.58, alpha: 1) : .secondaryLabelColor)
        let label = "\(line)" as NSString
        let size = label.size(withAttributes: [.font: font])
        let origin = NSPoint(x: ruleThickness - size.width - 6, y: y + (height - size.height) / 2)
        label.draw(at: origin, withAttributes: [.font: font, .foregroundColor: color])
    }
}

enum CodePalette {
    static let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

    static func apply(to textView: NSTextView, errorLine: Int?) {
        let dark = textView.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let palette = dark ? darkPalette : lightPalette
        textView.backgroundColor = palette.background
        textView.drawsBackground = true
        textView.insertionPointColor = palette.plain
        textView.selectedTextAttributes = [
            .backgroundColor: palette.selection,
            .foregroundColor: palette.plain,
        ]
        guard let storage = textView.textStorage else { return }
        let full = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.setAttributes([
            .font: font,
            .foregroundColor: palette.plain,
        ], range: full)
        let source = storage.string
        for span in CodeHighlight.spans(in: source) {
            let range = NSRange(location: span.location, length: span.length)
            guard range.location >= 0, NSMaxRange(range) <= storage.length else { continue }
            var attributes: [NSAttributedString.Key: Any] = [.foregroundColor: color(span.token, palette)]
            if span.token == .comment {
                attributes[.font] = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
            }
            storage.addAttributes(attributes, range: range)
        }
        if let errorLine, let range = lineRange(errorLine, in: source as NSString), NSMaxRange(range) <= storage.length {
            storage.addAttribute(.backgroundColor, value: NSColor.systemRed.withAlphaComponent(0.28), range: range)
        }
        storage.endEditing()
    }

    static func lineRange(_ line: Int, in text: NSString) -> NSRange? {
        guard line > 0 else { return nil }
        if text.length == 0 { return line == 1 ? NSRange(location: 0, length: 0) : nil }
        var current = 1
        var index = 0
        while index <= text.length {
            if index == text.length { return current == line ? NSRange(location: index, length: 0) : nil }
            let range = text.lineRange(for: NSRange(location: index, length: 0))
            if current == line { return range }
            let next = NSMaxRange(range)
            if next <= index { return nil }
            index = next
            current += 1
        }
        return nil
    }

    private struct Palette {
        var plain: NSColor
        var keyword: NSColor
        var string: NSColor
        var number: NSColor
        var comment: NSColor
        var tag: NSColor
        var key: NSColor
        var punctuation: NSColor
        var braces: [NSColor]
        var background: NSColor
        var selection: NSColor
    }

    private static let darkPalette = Palette(
        plain: NSColor(srgbRed: 0.83, green: 0.83, blue: 0.83, alpha: 1),
        keyword: NSColor(srgbRed: 0.78, green: 0.53, blue: 0.75, alpha: 1),
        string: NSColor(srgbRed: 0.81, green: 0.57, blue: 0.47, alpha: 1),
        number: NSColor(srgbRed: 0.71, green: 0.81, blue: 0.66, alpha: 1),
        comment: NSColor(srgbRed: 0.42, green: 0.60, blue: 0.33, alpha: 1),
        tag: NSColor(srgbRed: 0.34, green: 0.61, blue: 0.84, alpha: 1),
        key: NSColor(srgbRed: 0.61, green: 0.86, blue: 1, alpha: 1),
        punctuation: NSColor(srgbRed: 0.86, green: 0.86, blue: 0.67, alpha: 1),
        braces: [
            NSColor(srgbRed: 0.96, green: 0.80, blue: 0.35, alpha: 1),
            NSColor(srgbRed: 0.78, green: 0.53, blue: 0.96, alpha: 1),
            NSColor(srgbRed: 0.40, green: 0.80, blue: 0.93, alpha: 1),
            NSColor(srgbRed: 0.45, green: 0.86, blue: 0.58, alpha: 1),
        ],
        background: NSColor(srgbRed: 0.11, green: 0.11, blue: 0.13, alpha: 1),
        selection: NSColor(srgbRed: 0.20, green: 0.38, blue: 0.64, alpha: 1)
    )

    private static let lightPalette = Palette(
        plain: NSColor(srgbRed: 0.12, green: 0.12, blue: 0.14, alpha: 1),
        keyword: NSColor(srgbRed: 0.69, green: 0.00, blue: 0.86, alpha: 1),
        string: NSColor(srgbRed: 0.64, green: 0.08, blue: 0.08, alpha: 1),
        number: NSColor(srgbRed: 0.04, green: 0.53, blue: 0.35, alpha: 1),
        comment: NSColor(srgbRed: 0.00, green: 0.50, blue: 0.00, alpha: 1),
        tag: NSColor(srgbRed: 0.50, green: 0.00, blue: 0.00, alpha: 1),
        key: NSColor(srgbRed: 0.02, green: 0.32, blue: 0.65, alpha: 1),
        punctuation: NSColor(srgbRed: 0.35, green: 0.35, blue: 0.20, alpha: 1),
        braces: [
            NSColor(srgbRed: 0.72, green: 0.45, blue: 0.00, alpha: 1),
            NSColor(srgbRed: 0.45, green: 0.18, blue: 0.72, alpha: 1),
            NSColor(srgbRed: 0.00, green: 0.40, blue: 0.70, alpha: 1),
            NSColor(srgbRed: 0.05, green: 0.48, blue: 0.28, alpha: 1),
        ],
        background: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 1),
        selection: NSColor(srgbRed: 0.70, green: 0.84, blue: 1, alpha: 1)
    )

    private static func color(_ token: CodeHighlight.Token, _ palette: Palette) -> NSColor {
        switch token {
        case .keyword: return palette.keyword
        case .string: return palette.string
        case .number: return palette.number
        case .comment: return palette.comment
        case .tag: return palette.tag
        case .key: return palette.key
        case .punctuation: return palette.punctuation
        case let .brace(level): return palette.braces[(level - 1) % palette.braces.count]
        }
    }
}
