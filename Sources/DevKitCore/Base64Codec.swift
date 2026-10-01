import Foundation

public enum Base64Codec {
    public enum Alphabet: String, Sendable {
        case standard, urlSafe
    }

    public enum Direction: String, Sendable {
        case encode, decode
    }

    public static func convert(_ text: String, direction: Direction, alphabet: Alphabet) -> ToolResult {
        if let issue = InputChecks.issue(for: text, emptyPrompt: direction == .encode ? "Enter text to encode." : "Enter Base64 to decode.") {
            return .failure(issue)
        }
        switch direction {
        case .encode:
            return .success(encode(Data(text.utf8), alphabet: alphabet))
        case .decode:
            guard let data = decode(text, alphabet: alphabet) else {
                return .failure("Input is not valid Base64.")
            }
            if data.contains(0) {
                return .success("Decoded \(data.count) bytes of binary data. Use Decode File or save the bytes from a file workflow. Text preview omitted.")
            }
            let decoded = String(decoding: data, as: UTF8.self)
            if decoded.utf8.contains(0) {
                return .failure("Decoded bytes are not valid text. Load a file and decode it to disk from the tool.")
            }
            return .success(String(data: data, encoding: .utf8) ?? decoded)
        }
    }

    public static func encode(_ data: Data, alphabet: Alphabet) -> String {
        let standard = data.base64EncodedString()
        switch alphabet {
        case .standard:
            return standard
        case .urlSafe:
            return standard
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
    }

    public static func decode(_ text: String, alphabet: Alphabet) -> Data? {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.replacingOccurrences(of: "\\s", with: "", options: .regularExpression)
        if cleaned.isEmpty { return nil }
        let alphabetSet = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=-_")
        let payload = cleaned.unicodeScalars.filter { alphabetSet.contains($0) && $0 != "=" }
        if payload.isEmpty { return nil }
        switch alphabet {
        case .urlSafe:
            cleaned = cleaned.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
            let remainder = cleaned.count % 4
            if remainder > 0 {
                cleaned += String(repeating: "=", count: 4 - remainder)
            }
        case .standard:
            break
        }
        return Data(base64Encoded: cleaned, options: [.ignoreUnknownCharacters])
    }
}
