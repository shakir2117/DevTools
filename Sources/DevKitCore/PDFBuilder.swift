import Foundation
import PDFKit
import AppKit
import CoreText

public enum PDFBuilder {
    public struct PageSpec: Sendable {
        public var text: String
        public var markdown: Bool
        public var html: Bool
        public var imageData: Data?
        public init(text: String = "", markdown: Bool = false, html: Bool = false, imageData: Data? = nil) {
            self.text = text
            self.markdown = markdown
            self.html = html
            self.imageData = imageData
        }
    }

    public static func make(pages: [PageSpec], pageSize: CGSize, margin: CGFloat) -> Data? {
        let document = PDFDocument()
        for spec in pages {
            if let imageData = spec.imageData, let image = NSImage(data: imageData), let page = imagePage(image, size: pageSize, margin: margin) {
                document.insert(page, at: document.pageCount)
                continue
            }
            let body = attributed(spec)
            for page in textPages(body, size: pageSize, margin: margin) {
                document.insert(page, at: document.pageCount)
            }
        }
        guard document.pageCount > 0 else { return nil }
        return document.dataRepresentation()
    }

    public static func merge(_ documents: [Data]) -> Data? {
        let combined = PDFDocument()
        for data in documents {
            guard let document = PDFDocument(data: data) else { continue }
            for index in 0..<document.pageCount {
                guard let page = document.page(at: index) else { continue }
                combined.insert(page, at: combined.pageCount)
            }
        }
        guard combined.pageCount > 0 else { return nil }
        return combined.dataRepresentation()
    }

    public static func reorder(_ data: Data, order: [Int]) -> Data? {
        guard let document = PDFDocument(data: data) else { return nil }
        let next = PDFDocument()
        for index in order where document.page(at: index) != nil {
            if let page = document.page(at: index) {
                next.insert(page, at: next.pageCount)
            }
        }
        guard next.pageCount > 0 else { return nil }
        return next.dataRepresentation()
    }

    public static func pageCount(_ data: Data) -> Int {
        PDFDocument(data: data)?.pageCount ?? 0
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        let letter = CGSize(width: 612, height: 792)
        let first = make(pages: [PageSpec(text: "Hello DevKit")], pageSize: letter, margin: 36)
        expect("pdf text", first.map(pageCount) == 1)
        let second = make(pages: [PageSpec(text: "Second")], pageSize: letter, margin: 36)
        if let first, let second, let merged = merge([first, second]) {
            expect("pdf merge", pageCount(merged) == 2)
            if let flipped = reorder(merged, order: [1, 0]) {
                expect("pdf reorder", pageCount(flipped) == 2)
            } else {
                expect("pdf reorder", false)
            }
        } else {
            expect("pdf merge", false)
            expect("pdf reorder", false)
        }
        let html = make(pages: [PageSpec(text: "<h1>Hi</h1>", html: true)], pageSize: letter, margin: 36)
        expect("pdf html", html.map(pageCount) == 1)
        expect("pdf empty", make(pages: [PageSpec(text: "")], pageSize: letter, margin: 36) == nil)
    }

    private static func attributed(_ spec: PageSpec) -> NSAttributedString {
        if spec.markdown {
            let html = MarkdownRender.html(from: spec.text).output
            return htmlAttributed(html) ?? NSAttributedString(string: spec.text)
        }
        if spec.html {
            return htmlAttributed(spec.text) ?? NSAttributedString(string: spec.text)
        }
        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        return NSAttributedString(string: spec.text, attributes: [.font: font, .foregroundColor: NSColor.black])
    }

    private static func htmlAttributed(_ html: String) -> NSAttributedString? {
        guard let data = html.data(using: .utf8) else { return nil }
        return try? NSAttributedString(data: data, options: [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue,
        ], documentAttributes: nil)
    }

    private static func textPages(_ text: NSAttributedString, size: CGSize, margin: CGFloat) -> [PDFPage] {
        if text.length == 0 { return [] }
        let contentWidth = size.width - margin * 2
        let contentHeight = size.height - margin * 2
        let framesetter = CTFramesetterCreateWithAttributedString(text)
        var pages: [PDFPage] = []
        var index = 0
        while index < text.length && pages.count < 200 {
            let path = CGPath(rect: CGRect(x: 0, y: 0, width: contentWidth, height: contentHeight), transform: nil)
            let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: index, length: 0), path, nil)
            let visible = CTFrameGetVisibleStringRange(frame)
            if visible.length == 0 { break }
            if let page = draw(frame: frame, size: size, margin: margin) {
                pages.append(page)
            }
            index += visible.length
        }
        return pages
    }

    private static func draw(frame: CTFrame, size: CGSize, margin: CGFloat) -> PDFPage? {
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else { return nil }
        var media = CGRect(origin: .zero, size: size)
        guard let context = CGContext(consumer: consumer, mediaBox: &media, nil) else { return nil }
        context.beginPDFPage(nil)
        context.setFillColor(NSColor.white.cgColor)
        context.fill(media)
        context.translateBy(x: margin, y: margin)
        CTFrameDraw(frame, context)
        context.endPDFPage()
        context.closePDF()
        return PDFDocument(data: data as Data)?.page(at: 0)
    }

    private static func imagePage(_ image: NSImage, size: CGSize, margin: CGFloat) -> PDFPage? {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else { return nil }
        var media = CGRect(origin: .zero, size: size)
        guard let context = CGContext(consumer: consumer, mediaBox: &media, nil) else { return nil }
        context.beginPDFPage(nil)
        context.setFillColor(NSColor.white.cgColor)
        context.fill(media)
        let available = CGRect(x: margin, y: margin, width: size.width - margin * 2, height: size.height - margin * 2)
        let scale = min(available.width / CGFloat(cg.width), available.height / CGFloat(cg.height))
        let fitted = CGSize(width: CGFloat(cg.width) * scale, height: CGFloat(cg.height) * scale)
        let rect = CGRect(x: available.midX - fitted.width / 2, y: available.midY - fitted.height / 2, width: fitted.width, height: fitted.height)
        context.draw(cg, in: rect)
        context.endPDFPage()
        context.closePDF()
        return PDFDocument(data: data as Data)?.page(at: 0)
    }
}
