import Foundation

public enum HTMLEntities {
    public enum Style: String, Sendable {
        case named, decimal, hexadecimal
    }

    public enum Direction: String, Sendable {
        case encode, decode
    }

    public static func convert(_ text: String, direction: Direction, style: Style) -> ToolResult {
        if text.count > 5_000_000 {
            return .failure("Input is larger than 5 MB. Open a smaller excerpt.")
        }
        if let issue = InputChecks.issue(for: text, emptyPrompt: direction == .encode ? "Enter text to encode." : "Enter HTML entities to decode.") {
            return .failure(issue)
        }
        switch direction {
        case .encode:
            return .success(encode(text, style: style))
        case .decode:
            return .success(decode(text))
        }
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        let encoded = convert(#"a<b>&"c""#, direction: .encode, style: .named)
        expect("html named encode", encoded.output == "a&lt;b&gt;&amp;&quot;c&quot;" && encoded.issue == nil)
        let decoded = convert(encoded.output, direction: .decode, style: .named)
        expect("html named roundtrip", decoded.output == #"a<b>&"c""#)
        let numeric = convert("<", direction: .encode, style: .decimal)
        expect("html decimal", numeric.output == "&#60;")
        let hex = convert("<", direction: .encode, style: .hexadecimal)
        expect("html hex", hex.output == "&#x3c;")
        let fromNumeric = convert("&#60;&#x3e;&amp;", direction: .decode, style: .decimal)
        expect("html numeric decode", fromNumeric.output == "<>&")
        let emoji = convert("é", direction: .encode, style: .named)
        expect("html named latin", emoji.output == "&eacute;")
        expect("html empty", convert("  ", direction: .encode, style: .named).issue != nil)
        expect("html binary", convert(String(repeating: "\u{0}", count: 4), direction: .decode, style: .named).issue != nil)
    }

    private static func encode(_ text: String, style: Style) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        for scalar in text.unicodeScalars {
            let value = scalar.value
            if style == .named, let name = namesByCode[value] {
                result += "&\(name);"
                continue
            }
            let special = value == 38 || value == 60 || value == 62 || value == 34 || value == 39
            if special || value > 126 || value < 32 {
                switch style {
                case .hexadecimal:
                    result += "&#x\(String(value, radix: 16));"
                case .decimal, .named:
                    result += "&#\(value);"
                }
            } else {
                result.unicodeScalars.append(scalar)
            }
        }
        return result
    }

    private static func decode(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        var index = text.startIndex
        while index < text.endIndex {
            if text[index] == "&",
               let end = text[index...].firstIndex(of: ";"),
               text.distance(from: index, to: end) <= 64 {
                let token = String(text[text.index(after: index)..<end])
                if let scalar = decodeToken(token) {
                    result.unicodeScalars.append(scalar)
                    index = text.index(after: end)
                    continue
                }
            }
            result.append(text[index])
            index = text.index(after: index)
        }
        return result
    }

    private static func decodeToken(_ token: String) -> Unicode.Scalar? {
        if token.hasPrefix("#x") || token.hasPrefix("#X") {
            let digits = token.dropFirst(2)
            guard let value = UInt32(digits, radix: 16), let scalar = Unicode.Scalar(value) else { return nil }
            return scalar
        }
        if token.hasPrefix("#") {
            let digits = token.dropFirst()
            guard let value = UInt32(digits, radix: 10), let scalar = Unicode.Scalar(value) else { return nil }
            return scalar
        }
        guard let code = codesByName[token], let scalar = Unicode.Scalar(code) else { return nil }
        return scalar
    }

    private static let namedPairs: [(String, UInt32)] = [
        ("amp", 38), ("lt", 60), ("gt", 62), ("quot", 34), ("apos", 39), ("nbsp", 160),
        ("iexcl", 161), ("cent", 162), ("pound", 163), ("curren", 164), ("yen", 165),
        ("brvbar", 166), ("sect", 167), ("uml", 168), ("copy", 169), ("ordf", 170),
        ("laquo", 171), ("not", 172), ("shy", 173), ("reg", 174), ("macr", 175),
        ("deg", 176), ("plusmn", 177), ("sup2", 178), ("sup3", 179), ("acute", 180),
        ("micro", 181), ("para", 182), ("middot", 183), ("cedil", 184), ("sup1", 185),
        ("ordm", 186), ("raquo", 187), ("frac14", 188), ("frac12", 189), ("frac34", 190),
        ("iquest", 191), ("Agrave", 192), ("Aacute", 193), ("Acirc", 194), ("Atilde", 195),
        ("Auml", 196), ("Aring", 197), ("AElig", 198), ("Ccedil", 199), ("Egrave", 200),
        ("Eacute", 201), ("Ecirc", 202), ("Euml", 203), ("Igrave", 204), ("Iacute", 205),
        ("Icirc", 206), ("Iuml", 207), ("ETH", 208), ("Ntilde", 209), ("Ograve", 210),
        ("Oacute", 211), ("Ocirc", 212), ("Otilde", 213), ("Ouml", 214), ("times", 215),
        ("Oslash", 216), ("Ugrave", 217), ("Uacute", 218), ("Ucirc", 219), ("Uuml", 220),
        ("Yacute", 221), ("THORN", 222), ("szlig", 223), ("agrave", 224), ("aacute", 225),
        ("acirc", 226), ("atilde", 227), ("auml", 228), ("aring", 229), ("aelig", 230),
        ("ccedil", 231), ("egrave", 232), ("eacute", 233), ("ecirc", 234), ("euml", 235),
        ("igrave", 236), ("iacute", 237), ("icirc", 238), ("iuml", 239), ("eth", 240),
        ("ntilde", 241), ("ograve", 242), ("oacute", 243), ("ocirc", 244), ("otilde", 245),
        ("ouml", 246), ("divide", 247), ("oslash", 248), ("ugrave", 249), ("uacute", 250),
        ("ucirc", 251), ("uuml", 252), ("yacute", 253), ("thorn", 254), ("yuml", 255),
        ("euro", 8364), ("hellip", 8230), ("ndash", 8211), ("mdash", 8212),
        ("lsquo", 8216), ("rsquo", 8217), ("ldquo", 8220), ("rdquo", 8221),
        ("bull", 8226), ("trade", 8482), ("minus", 8722),
    ]

    private static let codesByName: [String: UInt32] = Dictionary(uniqueKeysWithValues: namedPairs.map { ($0.0, $0.1) })
    private static let namesByCode: [UInt32: String] = Dictionary(uniqueKeysWithValues: namedPairs.map { ($0.1, $0.0) })
}
