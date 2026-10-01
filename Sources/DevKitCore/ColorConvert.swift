import Foundation

public struct RGBA: Equatable, Sendable {
    public var r: Double
    public var g: Double
    public var b: Double
    public var a: Double

    public init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.r = min(1, max(0, r))
        self.g = min(1, max(0, g))
        self.b = min(1, max(0, b))
        self.a = min(1, max(0, a))
    }
}

public enum ColorConvert {
    public static func parse(_ text: String) -> Result<RGBA, ToolIssue> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .failure(ToolIssue(message: "Enter a color.")) }
        let lower = trimmed.lowercased()
        if lower.hasPrefix("#") || isHex(lower) {
            if let color = parseHex(lower) { return .success(color) }
            return .failure(ToolIssue(message: "Hex colors look like #RGB, #RRGGBB, or #RRGGBBAA."))
        }
        if lower.hasPrefix("hsl") {
            guard let color = parseComponents(lower, prefix: "hsl", count: 3, hue: true) else {
                return .failure(ToolIssue(message: "HSL looks like hsl(210, 50%, 40%)."))
            }
            return .success(hslToRGB(color.0, color.1, color.2, color.3))
        }
        if lower.hasPrefix("hsb") || lower.hasPrefix("hsv") {
            let prefix = lower.hasPrefix("hsb") ? "hsb" : "hsv"
            guard let color = parseComponents(lower, prefix: prefix, count: 3, hue: true) else {
                return .failure(ToolIssue(message: "HSB looks like hsb(210, 50%, 40%)."))
            }
            return .success(hsbToRGB(color.0, color.1, color.2, color.3))
        }
        if lower.hasPrefix("cmyk") {
            guard let color = parseComponents(lower, prefix: "cmyk", count: 4, hue: false) else {
                return .failure(ToolIssue(message: "CMYK looks like cmyk(0%, 100%, 100%, 0%)."))
            }
            return .success(cmykToRGB(color.0, color.1, color.2, color.3))
        }
        if lower.hasPrefix("rgb") {
            guard let color = parseComponents(lower, prefix: "rgb", count: 3, hue: false) else {
                return .failure(ToolIssue(message: "RGB looks like rgb(51, 102, 153)."))
            }
            return .success(RGBA(r: color.0, g: color.1, b: color.2, a: color.3))
        }
        if let color = parseBare(lower) {
            return .success(RGBA(r: color.0 / 255, g: color.1 / 255, b: color.2 / 255, a: color.3 > 1 ? color.3 / 255 : color.3))
        }
        return .failure(ToolIssue(message: "Use hex, rgb(), hsl(), hsb(), or cmyk()."))
    }

    public static func describe(_ color: RGBA) -> String {
        let rgb = rgb255(color)
        let hsl = rgbToHSL(color)
        let hsb = rgbToHSB(color)
        let cmyk = rgbToCMYK(color)
        return [
            "HEX: \(hex(color))",
            String(format: "RGB: rgb(%.0f, %.0f, %.0f)", rgb.0, rgb.1, rgb.2),
            String(format: "HSL: hsl(%.1f, %.1f%%, %.1f%%)", hsl.0, hsl.1 * 100, hsl.2 * 100),
            String(format: "HSB: hsb(%.1f, %.1f%%, %.1f%%)", hsb.0, hsb.1 * 100, hsb.2 * 100),
            String(format: "CMYK: cmyk(%.1f%%, %.1f%%, %.1f%%, %.1f%%)", cmyk.0 * 100, cmyk.1 * 100, cmyk.2 * 100, cmyk.3 * 100),
            String(format: "Alpha: %.3f", color.a),
            String(format: "CSS: rgba(%.0f, %.0f, %.0f, %.3f)", rgb.0, rgb.1, rgb.2, color.a),
            String(format: "Swift: NSColor(red: %.4f, green: %.4f, blue: %.4f, alpha: %.4f)", color.r, color.g, color.b, color.a),
            String(format: "SwiftUI: Color(red: %.4f, green: %.4f, blue: %.4f, opacity: %.4f)", color.r, color.g, color.b, color.a),
        ].joined(separator: "\n")
    }

    public static func convert(_ text: String) -> ToolResult {
        if text.count > 200 { return .failure("That input is too long to be a color.") }
        switch parse(text) {
        case let .success(color): return .success(describe(color))
        case let .failure(issue): return .failure(issue)
        }
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        let red = convert("#ff0000")
        expect("color hex", red.output.contains("rgb(255, 0, 0)") && red.output.contains("#FF0000"))
        let back = convert("rgb(51, 102, 153)")
        expect("color rgb", back.output.contains("#336699"))
        let hsl = convert("hsl(0, 100%, 50%)")
        expect("color hsl", hsl.output.contains("#FF0000"))
        let cmyk = convert("cmyk(0%, 100%, 100%, 0%)")
        expect("color cmyk", cmyk.output.contains("#FF0000"))
        expect("color empty", convert(" ").issue != nil)
        expect("color bad", convert("nope").issue != nil)
        if case let .success(parsed) = parse("#336699") {
            let again = parse(hex(parsed))
            if case let .success(round) = again {
                expect("color roundtrip", abs(parsed.r - round.r) < 0.01 && abs(parsed.g - round.g) < 0.01 && abs(parsed.b - round.b) < 0.01)
            } else {
                expect("color roundtrip", false)
            }
        } else {
            expect("color roundtrip", false)
        }
    }

    public static func hex(_ color: RGBA) -> String {
        let rgb = rgb255(color)
        if color.a < 0.999 {
            return String(format: "#%02X%02X%02X%02X", Int(rgb.0.rounded()), Int(rgb.1.rounded()), Int(rgb.2.rounded()), Int((color.a * 255).rounded()))
        }
        return String(format: "#%02X%02X%02X", Int(rgb.0.rounded()), Int(rgb.1.rounded()), Int(rgb.2.rounded()))
    }

    private static func rgb255(_ color: RGBA) -> (Double, Double, Double) {
        (color.r * 255, color.g * 255, color.b * 255)
    }

    private static func isHex(_ text: String) -> Bool {
        let body = text.hasPrefix("#") ? String(text.dropFirst()) : text
        guard [3, 4, 6, 8].contains(body.count) else { return false }
        return body.allSatisfy { $0.isHexDigit }
    }

    private static func parseHex(_ text: String) -> RGBA? {
        var body = text.hasPrefix("#") ? String(text.dropFirst()) : text
        guard isHex(body) else { return nil }
        if body.count == 3 || body.count == 4 {
            body = body.map { "\($0)\($0)" }.joined()
        }
        guard let value = UInt64(body, radix: 16) else { return nil }
        if body.count == 8 {
            return RGBA(
                r: Double((value >> 24) & 0xff) / 255,
                g: Double((value >> 16) & 0xff) / 255,
                b: Double((value >> 8) & 0xff) / 255,
                a: Double(value & 0xff) / 255
            )
        }
        return RGBA(
            r: Double((value >> 16) & 0xff) / 255,
            g: Double((value >> 8) & 0xff) / 255,
            b: Double(value & 0xff) / 255
        )
    }

    private static func parseComponents(_ text: String, prefix: String, count: Int, hue: Bool) -> (Double, Double, Double, Double)? {
        guard let open = text.firstIndex(of: "("), let close = text.lastIndex(of: ")") else { return nil }
        let body = text[text.index(after: open)..<close]
        let parts = body.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == count || parts.count == count + 1 else { return nil }
        func raw(_ part: String) -> (Double, Bool)? {
            let percent = part.hasSuffix("%")
            let digits = percent ? String(part.dropLast()) : part
            guard let value = Double(digits) else { return nil }
            return (value, percent)
        }
        var values: [(Double, Bool)] = []
        for part in parts {
            guard let parsed = raw(part) else { return nil }
            values.append(parsed)
        }
        func unit(_ item: (Double, Bool), scale: Double) -> Double {
            item.1 ? item.0 / 100 : item.0 / scale
        }
        if hue {
            let h = values[0].0.truncatingRemainder(dividingBy: 360) / 360
            let s = unit(values[1], scale: values[1].0 > 1 ? 100 : 1)
            let l = unit(values[2], scale: values[2].0 > 1 ? 100 : 1)
            let a = values.count > 3 ? (values[3].0 > 1 && !values[3].1 ? values[3].0 / 255 : values[3].1 ? values[3].0 / 100 : values[3].0) : 1
            return (h, s, l, a)
        }
        if count == 4 {
            let c = unit(values[0], scale: values[0].0 > 1 ? 100 : 1)
            let m = unit(values[1], scale: values[1].0 > 1 ? 100 : 1)
            let y = unit(values[2], scale: values[2].0 > 1 ? 100 : 1)
            let k = unit(values[3], scale: values[3].0 > 1 ? 100 : 1)
            return (c, m, y, k)
        }
        let r = unit(values[0], scale: 255)
        let g = unit(values[1], scale: 255)
        let b = unit(values[2], scale: 255)
        let a: Double
        if values.count > 3 {
            a = values[3].1 ? values[3].0 / 100 : (values[3].0 > 1 ? values[3].0 / 255 : values[3].0)
        } else {
            a = 1
        }
        return (r, g, b, a)
    }

    private static func parseBare(_ text: String) -> (Double, Double, Double, Double)? {
        let parts = text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 3 || parts.count == 4 else { return nil }
        let numbers = parts.compactMap(Double.init)
        guard numbers.count == parts.count else { return nil }
        return (numbers[0], numbers[1], numbers[2], numbers.count == 4 ? (numbers[3] > 1 ? numbers[3] / 255 : numbers[3]) : 1)
    }

    private static func hslToRGB(_ h: Double, _ s: Double, _ l: Double, _ a: Double) -> RGBA {
        if s == 0 { return RGBA(r: l, g: l, b: l, a: a) }
        let q = l < 0.5 ? l * (1 + s) : l + s - l * s
        let p = 2 * l - q
        return RGBA(r: hue(p, q, h + 1 / 3), g: hue(p, q, h), b: hue(p, q, h - 1 / 3), a: a)
    }

    private static func hue(_ p: Double, _ q: Double, _ t: Double) -> Double {
        var t = t
        if t < 0 { t += 1 }
        if t > 1 { t -= 1 }
        if t < 1 / 6 { return p + (q - p) * 6 * t }
        if t < 1 / 2 { return q }
        if t < 2 / 3 { return p + (q - p) * (2 / 3 - t) * 6 }
        return p
    }

    private static func hsbToRGB(_ h: Double, _ s: Double, _ v: Double, _ a: Double) -> RGBA {
        let i = Int(h * 6) % 6
        let f = h * 6 - Double(Int(h * 6))
        let p = v * (1 - s)
        let q = v * (1 - f * s)
        let t = v * (1 - (1 - f) * s)
        let rgb: (Double, Double, Double)
        switch i {
        case 0: rgb = (v, t, p)
        case 1: rgb = (q, v, p)
        case 2: rgb = (p, v, t)
        case 3: rgb = (p, q, v)
        case 4: rgb = (t, p, v)
        default: rgb = (v, p, q)
        }
        return RGBA(r: rgb.0, g: rgb.1, b: rgb.2, a: a)
    }

    private static func cmykToRGB(_ c: Double, _ m: Double, _ y: Double, _ k: Double) -> RGBA {
        RGBA(r: (1 - c) * (1 - k), g: (1 - m) * (1 - k), b: (1 - y) * (1 - k))
    }

    private static func rgbToHSL(_ color: RGBA) -> (Double, Double, Double) {
        let maxC = max(color.r, color.g, color.b)
        let minC = min(color.r, color.g, color.b)
        let l = (maxC + minC) / 2
        let d = maxC - minC
        if d == 0 { return (0, 0, l) }
        let s = l > 0.5 ? d / (2 - maxC - minC) : d / (maxC + minC)
        let h: Double
        if maxC == color.r { h = ((color.g - color.b) / d).truncatingRemainder(dividingBy: 6) }
        else if maxC == color.g { h = (color.b - color.r) / d + 2 }
        else { h = (color.r - color.g) / d + 4 }
        return ((h < 0 ? h + 6 : h) / 6 * 360, s, l)
    }

    private static func rgbToHSB(_ color: RGBA) -> (Double, Double, Double) {
        let maxC = max(color.r, color.g, color.b)
        let minC = min(color.r, color.g, color.b)
        let d = maxC - minC
        let s = maxC == 0 ? 0 : d / maxC
        let h: Double
        if d == 0 { h = 0 }
        else if maxC == color.r { h = ((color.g - color.b) / d).truncatingRemainder(dividingBy: 6) }
        else if maxC == color.g { h = (color.b - color.r) / d + 2 }
        else { h = (color.r - color.g) / d + 4 }
        return ((h < 0 ? h + 6 : h) / 6 * 360, s, maxC)
    }

    private static func rgbToCMYK(_ color: RGBA) -> (Double, Double, Double, Double) {
        let k = 1 - max(color.r, color.g, color.b)
        if k >= 1 { return (0, 0, 0, 1) }
        return ((1 - color.r - k) / (1 - k), (1 - color.g - k) / (1 - k), (1 - color.b - k) / (1 - k), k)
    }
}
