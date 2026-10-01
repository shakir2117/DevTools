import Foundation
import CoreImage
import CoreGraphics
import ImageIO
import Vision
import UniformTypeIdentifiers

public enum QRCode {
    public static func payload(kind: String, text: String, ssid: String, password: String, security: String, name: String, phone: String, email: String) -> String {
        switch kind {
        case "wifi":
            return "WIFI:T:\(escape(security));S:\(escape(ssid));P:\(escape(password));;"
        case "vcard":
            return "BEGIN:VCARD\nVERSION:3.0\nFN:\(name)\nTEL:\(phone)\nEMAIL:\(email)\nEND:VCARD"
        default:
            return text
        }
    }

    public static func image(payload: String, correction: String, scale: Int, foreground: (Double, Double, Double), background: (Double, Double, Double)) -> CGImage? {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return nil }
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue(correction, forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let colored = falseColor(output, foreground: foreground, background: background) ?? output
        guard let small = CIContext().createCGImage(colored, from: colored.extent) else { return nil }
        let factor = max(1, min(scale, 40))
        let width = small.width * factor
        let height = small.height * factor
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .none
        context.draw(small, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    public static func png(payload: String, correction: String, scale: Int, foreground: (Double, Double, Double), background: (Double, Double, Double)) -> Data? {
        guard let image = image(payload: payload, correction: correction, scale: scale, foreground: foreground, background: background) else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    public static func pdf(payload: String, correction: String, scale: Int, foreground: (Double, Double, Double), background: (Double, Double, Double)) -> Data? {
        guard let image = image(payload: payload, correction: correction, scale: scale, foreground: foreground, background: background) else { return nil }
        let box = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else { return nil }
        var media = box
        guard let context = CGContext(consumer: consumer, mediaBox: &media, nil) else { return nil }
        context.beginPDFPage(nil)
        context.draw(image, in: box)
        context.endPDFPage()
        context.closePDF()
        return data as Data
    }

    public static func svg(payload: String, correction: String, foreground: (Double, Double, Double), background: (Double, Double, Double)) -> String? {
        guard let image = image(payload: payload, correction: correction, scale: 1, foreground: (0, 0, 0), background: (1, 1, 1)) else { return nil }
        guard let pixels = pixelBytes(image) else { return nil }
        let width = image.width
        let height = image.height
        var rects = ""
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                if pixels[offset] < 128 {
                    rects += "<rect x=\"\(x)\" y=\"\(y)\" width=\"1\" height=\"1\"/>"
                }
            }
        }
        let fill = String(format: "#%02X%02X%02X", Int(foreground.0 * 255), Int(foreground.1 * 255), Int(foreground.2 * 255))
        let back = String(format: "#%02X%02X%02X", Int(background.0 * 255), Int(background.1 * 255), Int(background.2 * 255))
        return "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 \(width) \(height)\" shape-rendering=\"crispEdges\"><rect width=\"100%\" height=\"100%\" fill=\"\(back)\"/><g fill=\"\(fill)\">\(rects)</g></svg>"
    }

    public static func read(data: Data) -> Result<[String], ToolIssue> {
        if data.isEmpty { return .failure(ToolIssue(message: "The image is empty.")) }
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        let handler = VNImageRequestHandler(data: data, options: [:])
        do {
            try handler.perform([request])
            let values = (request.results ?? []).compactMap { $0.payloadStringValue }.filter { !$0.isEmpty }
            if values.isEmpty { return .failure(ToolIssue(message: "No QR code was found.")) }
            return .success(values)
        } catch {
            return .failure(ToolIssue(message: error.localizedDescription))
        }
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        let png = png(payload: "DevKit", correction: "M", scale: 8, foreground: (0, 0, 0), background: (1, 1, 1))
        expect("qr png", png != nil && (png?.count ?? 0) > 100)
        if let png {
            if case let .success(values) = read(data: png) {
                expect("qr roundtrip", values.contains("DevKit"))
            } else {
                expect("qr roundtrip", false)
            }
        } else {
            expect("qr roundtrip", false)
        }
        let wifi = payload(kind: "wifi", text: "", ssid: "Lab", password: "secret", security: "WPA", name: "", phone: "", email: "")
        expect("qr wifi", wifi.contains("S:Lab") && wifi.contains("P:secret"))
        let svg = svg(payload: "DevKit", correction: "M", foreground: (0, 0, 0), background: (1, 1, 1))
        expect("qr svg", svg?.contains("<svg") == true && svg?.contains("<rect") == true)
        expect("qr empty read", read(data: Data()).isFailure)
        expect("qr empty image", image(payload: "  ", correction: "M", scale: 4, foreground: (0, 0, 0), background: (1, 1, 1)) == nil)
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: ":", with: "\\:")
    }

    private static func falseColor(_ image: CIImage, foreground: (Double, Double, Double), background: (Double, Double, Double)) -> CIImage? {
        guard let filter = CIFilter(name: "CIFalseColor") else { return nil }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIColor(red: foreground.0, green: foreground.1, blue: foreground.2), forKey: "inputColor0")
        filter.setValue(CIColor(red: background.0, green: background.1, blue: background.2), forKey: "inputColor1")
        return filter.outputImage
    }

    private static func pixelBytes(_ image: CGImage) -> [UInt8]? {
        let width = image.width
        let height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return bytes
    }
}

private extension Result where Failure == ToolIssue {
    var isFailure: Bool {
        if case .failure = self { return true }
        return false
    }
}
