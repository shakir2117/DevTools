import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

public enum ImageMeta {
    public static func report(_ data: Data) -> ToolResult {
        switch inspect(data) {
        case let .failure(issue):
            return .failure(issue)
        case let .success(info):
            return .success(info.text)
        }
    }

    public static func withoutLocation(_ data: Data) -> Result<(data: Data, note: String), ToolIssue> {
        if data.count > 20_000_000 { return .failure(ToolIssue(message: "Image is larger than 20 MB.")) }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 0 else {
            return .failure(ToolIssue(message: "That file is not an image ImageIO can read."))
        }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
        guard properties[kCGImagePropertyGPSDictionary] != nil else {
            return .success((data, "No location metadata."))
        }
        guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return .failure(ToolIssue(message: "Could not read the image pixels."))
        }
        let type = CGImageSourceGetType(source) ?? UTType.png.identifier as CFString
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, type, 1, nil) else {
            return .failure(ToolIssue(message: "Could not write the image."))
        }
        var kept = properties
        kept.removeValue(forKey: kCGImagePropertyGPSDictionary)
        CGImageDestinationAddImage(destination, image, kept as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            return .failure(ToolIssue(message: "Could not finish the image without location data."))
        }
        return .success((output as Data, "Removed location metadata."))
    }

    public static func examplePNG() -> Data? { samplePNG() }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        let png = examplePNG()
        expect("exif png", png != nil)
        let text = report(png ?? Data())
        expect("exif size", text.output.contains("Width: 8") && text.output.contains("Height: 8"))
        expect("exif gps", withoutLocation(png ?? Data()).map(\.note) == .success("No location metadata."))
        expect("exif junk", report(Data("nope".utf8)).issue != nil)
    }

    private static func inspect(_ data: Data) -> Result<(text: String, hasLocation: Bool), ToolIssue> {
        if data.count > 20_000_000 { return .failure(ToolIssue(message: "Image is larger than 20 MB.")) }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 0 else {
            return .failure(ToolIssue(message: "That file is not an image ImageIO can read."))
        }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
        let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 0
        let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 0
        let color = (properties[kCGImagePropertyColorModel] as? String) ?? "unknown"
        let profile = (properties[kCGImagePropertyProfileName] as? String) ?? "none"
        let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any]
        var lines = [
            "Width: \(width)",
            "Height: \(height)",
            "Color model: \(color)",
            "Color profile: \(profile)",
        ]
        if let gps {
            let lat = coordinate(gps, value: kCGImagePropertyGPSLatitude, ref: kCGImagePropertyGPSLatitudeRef)
            let lon = coordinate(gps, value: kCGImagePropertyGPSLongitude, ref: kCGImagePropertyGPSLongitudeRef)
            lines.append("Location: \(lat), \(lon)")
        } else {
            lines.append("Location: none")
        }
        return .success((lines.joined(separator: "\n"), gps != nil))
    }

    private static func coordinate(_ gps: [CFString: Any], value: CFString, ref: CFString) -> String {
        let number = (gps[value] as? NSNumber)?.doubleValue ?? 0
        let direction = gps[ref] as? String ?? ""
        return "\(number) \(direction)".trimmingCharacters(in: .whitespaces)
    }

    private static func samplePNG() -> Data? {
        let space = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: 8,
            height: 8,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let image = context.makeImage() else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
