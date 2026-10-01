import Foundation
import CryptoKit
import Security

public enum JWTCodec {
    public enum HMACAlgorithm: String, CaseIterable, Sendable {
        case hs256 = "HS256"
        case hs384 = "HS384"
        case hs512 = "HS512"

        var hash: Hashing.Algorithm {
            switch self {
            case .hs256: return .sha256
            case .hs384: return .sha384
            case .hs512: return .sha512
            }
        }
    }

    public static func describe(_ token: String, now: Date = Date()) -> ToolResult {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .failure("Paste a JWT to decode.") }
        if trimmed.count > 1_000_000 { return .failure("Token is too large.") }
        if trimmed.utf8.contains(0) { return .failure("Token looks like binary data.") }
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3 else {
            return .failure("A JWT has three Base64URL parts separated by dots.")
        }
        guard let headerData = Base64Codec.decode(parts[0], alphabet: .urlSafe),
              let headerText = String(data: headerData, encoding: .utf8),
              let payloadData = Base64Codec.decode(parts[1], alphabet: .urlSafe),
              let payloadText = String(data: payloadData, encoding: .utf8) else {
            return .failure("Header or payload is not valid Base64URL text.")
        }
        let prettyHeader = pretty(headerText)
        let prettyPayload = pretty(payloadText)
        var lines = [
            "Header:",
            prettyHeader,
            "",
            "Payload:",
            prettyPayload,
            "",
            "Signature:",
            parts[2].isEmpty ? "(empty)" : parts[2],
            "",
            "Signature: not verified",
        ]
        lines.append(contentsOf: claimLines(payloadText, now: now))
        return .success(lines.joined(separator: "\n"))
    }

    public static func sign(header: String, payload: String, secret: String, algorithm: HMACAlgorithm) -> ToolResult {
        guard let compactHeader = compactObject(header) else {
            return compactFailure(header, what: "Header")
        }
        guard let compactPayload = compactObject(payload) else {
            return compactFailure(payload, what: "Payload")
        }
        let stamped = upsertAlgorithm(compactHeader, algorithm: algorithm.rawValue)
        let headerPart = Base64Codec.encode(Data(stamped.utf8), alphabet: .urlSafe)
        let payloadPart = Base64Codec.encode(Data(compactPayload.utf8), alphabet: .urlSafe)
        let signingInput = "\(headerPart).\(payloadPart)"
        let mac = Hashing.digestHex(data: Data(signingInput.utf8), algorithm: algorithm.hash, hmacKey: Data(secret.utf8))
        guard let signature = Data(hex: mac) else {
            return .failure("Could not encode the HMAC.")
        }
        return .success("\(signingInput).\(Base64Codec.encode(signature, alphabet: .urlSafe))")
    }

    public static func verifyHMAC(token: String, secret: String, algorithm: HMACAlgorithm) -> ToolResult {
        guard let parts = parts(of: token) else {
            return .failure("A JWT has three Base64URL parts separated by dots.")
        }
        let signingInput = "\(parts[0]).\(parts[1])"
        let expected = Hashing.digestHex(data: Data(signingInput.utf8), algorithm: algorithm.hash, hmacKey: Data(secret.utf8))
        guard let actual = Base64Codec.decode(parts[2], alphabet: .urlSafe),
              let expectedData = Data(hex: expected) else {
            return .success("Invalid signature.")
        }
        let matches = constantTimeEqual(actual, expectedData)
        let headerAlg = algorithmName(in: parts[0])
        if matches && (headerAlg == nil || headerAlg == algorithm.rawValue) {
            return .success("Valid \(algorithm.rawValue) signature.")
        }
        if matches, let headerAlg, headerAlg != algorithm.rawValue {
            return .success("Signature matches \(algorithm.rawValue), but the header says \(headerAlg).")
        }
        return .success("Invalid signature.")
    }

    public static func verifyRS256(token: String, pem: String) -> ToolResult {
        guard let parts = parts(of: token) else {
            return .failure("A JWT has three Base64URL parts separated by dots.")
        }
        guard let signature = Base64Codec.decode(parts[2], alphabet: .urlSafe) else {
            return .success("Invalid signature.")
        }
        guard let key = rsaPublicKey(pem: pem) else {
            return .failure("Could not read an RSA public key from that PEM.")
        }
        let message = Data("\(parts[0]).\(parts[1])".utf8)
        var error: Unmanaged<CFError>?
        let ok = SecKeyVerifySignature(
            key,
            .rsaSignatureMessagePKCS1v15SHA256,
            message as CFData,
            signature as CFData,
            &error
        )
        if ok { return .success("Valid RS256 signature.") }
        return .success("Invalid signature.")
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        let header = #"{"alg":"HS256","typ":"JWT"}"#
        let payload = #"{"sub":"1234567890","name":"John Doe","iat":1516239022}"#
        let signed = sign(header: header, payload: payload, secret: "your-256-bit-secret", algorithm: .hs256)
        let known = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
        expect("jwt hs256 known", signed.output == known)
        let verified = verifyHMAC(token: known, secret: "your-256-bit-secret", algorithm: .hs256)
        expect("jwt hs256 verify", verified.output == "Valid HS256 signature.")
        let wrong = verifyHMAC(token: known, secret: "nope", algorithm: .hs256)
        expect("jwt hs256 reject", wrong.output == "Invalid signature.")
        let expiredPayload = #"{"exp":1}"#
        let expired = sign(header: header, payload: expiredPayload, secret: "secret", algorithm: .hs256)
        let described = describe(expired.output, now: Date(timeIntervalSince1970: 1_700_000_000))
        expect("jwt expired badge", described.output.contains("expired"))
        let future = sign(header: header, payload: #"{"exp":4102444800,"nbf":4102444800}"#, secret: "secret", algorithm: .hs256)
        let futureText = describe(future.output, now: Date(timeIntervalSince1970: 1_700_000_000))
        expect("jwt not yet valid", futureText.output.contains("not yet valid"))
        expect("jwt empty", describe("  ").issue != nil)
        expect("jwt malformed", describe("not-a-jwt").issue != nil)
        expect("jwt binary", describe(String(repeating: "\u{0}", count: 4)).issue != nil)

        let pair = rsaPair()
        expect("jwt rsa key", pair != nil)
        if let pair {
            let token = rs256Token(privateKey: pair.privateKey, header: #"{"alg":"RS256","typ":"JWT"}"#, payload: #"{"sub":"devkit"}"#)
            let pem = pkcs1PEM(pair.publicData)
            let ok = verifyRS256(token: token, pem: pem)
            expect("jwt rs256 verify", ok.output == "Valid RS256 signature.")
            let spki = spkiPEM(pair.publicData)
            let viaSPKI = verifyRS256(token: token, pem: spki)
            expect("jwt rs256 spki", viaSPKI.output == "Valid RS256 signature.")
            let bad = verifyRS256(token: token + "aa", pem: pem)
            expect("jwt rs256 reject", bad.output != "Valid RS256 signature.")
        }
    }

    private static func claimLines(_ payload: String, now: Date) -> [String] {
        guard let data = payload.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }
        var lines: [String] = [""]
        for key in ["exp", "iat", "nbf"] {
            guard let number = jsonNumber(object[key]) else { continue }
            let date = Date(timeIntervalSince1970: number)
            let formatted = iso(date)
            let badge: String
            switch key {
            case "exp":
                badge = date < now ? "expired" : "valid"
            case "nbf":
                badge = date > now ? "not yet valid" : "valid"
            default:
                badge = "issued"
            }
            lines.append("\(key): \(formatted) (\(badge))")
        }
        return lines
    }

    private static func jsonNumber(_ value: Any?) -> TimeInterval? {
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() { return nil }
            return number.doubleValue
        }
        return nil
    }

    private static func iso(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private static func pretty(_ json: String) -> String {
        let formatted = JSONFormatter.format(json, mode: .beautify, indent: .two, sortKeys: false)
        return formatted.issue == nil ? formatted.output : json
    }

    private static func parts(of token: String) -> [String]? {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3, !parts[0].isEmpty, !parts[1].isEmpty else { return nil }
        return parts
    }

    private static func compactObject(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              object is NSDictionary else { return nil }
        return stripJSONWhitespace(trimmed)
    }

    private static func compactFailure(_ text: String, what: String) -> ToolResult {
        let formatted = JSONFormatter.format(text, mode: .validate, indent: .two, sortKeys: false)
        if let issue = formatted.issue {
            return .failure("\(what) \(issue.message)", line: issue.line, column: issue.column)
        }
        return .failure("\(what) must be a JSON object.")
    }

    private static func stripJSONWhitespace(_ text: String) -> String {
        var result = ""
        var inString = false
        var escaped = false
        for character in text {
            if inString {
                result.append(character)
                if escaped {
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    inString = false
                }
            } else if character == "\"" {
                inString = true
                result.append(character)
            } else if !character.isWhitespace {
                result.append(character)
            }
        }
        return result
    }

    private static func upsertAlgorithm(_ json: String, algorithm: String) -> String {
        guard let algRange = json.range(of: "\"alg\"") else {
            if json == "{}" { return "{\"alg\":\"\(algorithm)\"}" }
            guard json.hasPrefix("{") else { return json }
            return "{\"alg\":\"\(algorithm)\"," + json.dropFirst()
        }
        var cursor = algRange.upperBound
        while cursor < json.endIndex, json[cursor].isWhitespace || json[cursor] == ":" {
            cursor = json.index(after: cursor)
        }
        guard cursor < json.endIndex, json[cursor] == "\"" else { return json }
        let valueStart = json.index(after: cursor)
        var valueEnd = valueStart
        var escaped = false
        while valueEnd < json.endIndex {
            let character = json[valueEnd]
            if escaped {
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else if character == "\"" {
                break
            }
            valueEnd = json.index(after: valueEnd)
        }
        guard valueEnd < json.endIndex else { return json }
        return String(json[..<valueStart]) + algorithm + String(json[valueEnd...])
    }

    private static func algorithmName(in headerPart: String) -> String? {
        guard let data = Base64Codec.decode(headerPart, alphabet: .urlSafe),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let alg = object["alg"] as? String else { return nil }
        return alg
    }

    private static func constantTimeEqual(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var diff: UInt8 = 0
        for (left, right) in zip(lhs, rhs) {
            diff |= left ^ right
        }
        return diff == 0
    }

    private static func rsaPublicKey(pem: String) -> SecKey? {
        guard let der = der(fromPEM: pem) else { return nil }
        if let key = makeRSAPublic(der) { return key }
        if let inner = spkiBitString(der), let key = makeRSAPublic(inner) { return key }
        return nil
    }

    private static func der(fromPEM pem: String) -> Data? {
        let lines = pem.split(whereSeparator: \.isNewline).map(String.init).filter { !$0.hasPrefix("-----") }
        let body = lines.joined().filter { !$0.isWhitespace }
        return Data(base64Encoded: body)
    }

    private static func makeRSAPublic(_ data: Data) -> SecKey? {
        let sizes: [Int?] = [nil, data.count * 8, 2048, 4096, 3072, 1024]
        for size in sizes {
            var attributes: [CFString: Any] = [
                kSecAttrKeyType: kSecAttrKeyTypeRSA,
                kSecAttrKeyClass: kSecAttrKeyClassPublic,
            ]
            if let size {
                attributes[kSecAttrKeySizeInBits] = size
            }
            var error: Unmanaged<CFError>?
            if let key = SecKeyCreateWithData(data as CFData, attributes as CFDictionary, &error) {
                return key
            }
        }
        return nil
    }

    private static func spkiBitString(_ der: Data) -> Data? {
        var cursor = DERCursor(data: der, index: 0)
        guard let sequence = cursor.tlv(), sequence.tag == 0x30 else { return nil }
        var inner = DERCursor(data: sequence.body, index: 0)
        guard inner.tlv() != nil, let bits = inner.tlv(), bits.tag == 0x03, let unused = bits.body.first, unused == 0 else {
            return nil
        }
        return Data(bits.body.dropFirst())
    }

    private static func rsaPair() -> (privateKey: SecKey, publicData: Data)? {
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 2048,
        ]
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error),
              let publicKey = SecKeyCopyPublicKey(privateKey),
              let publicData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            return nil
        }
        return (privateKey, publicData)
    }

    private static func rs256Token(privateKey: SecKey, header: String, payload: String) -> String {
        let headerPart = Base64Codec.encode(Data(stripJSONWhitespace(header).utf8), alphabet: .urlSafe)
        let payloadPart = Base64Codec.encode(Data(stripJSONWhitespace(payload).utf8), alphabet: .urlSafe)
        let signingInput = "\(headerPart).\(payloadPart)"
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey,
            .rsaSignatureMessagePKCS1v15SHA256,
            Data(signingInput.utf8) as CFData,
            &error
        ) as Data? else {
            return ""
        }
        return "\(signingInput).\(Base64Codec.encode(signature, alphabet: .urlSafe))"
    }

    private static func pkcs1PEM(_ data: Data) -> String {
        wrapPEM(data, label: "RSA PUBLIC KEY")
    }

    private static func spkiPEM(_ pkcs1: Data) -> String {
        let bitString = derTLV(tag: 0x03, body: Data([0x00]) + pkcs1)
        let oid = Data([0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00])
        let algorithm = derTLV(tag: 0x30, body: oid)
        let sequence = derTLV(tag: 0x30, body: algorithm + bitString)
        return wrapPEM(sequence, label: "PUBLIC KEY")
    }

    private static func wrapPEM(_ data: Data, label: String) -> String {
        let encoded = data.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed])
        return "-----BEGIN \(label)-----\n\(encoded)\n-----END \(label)-----"
    }

    private static func derTLV(tag: UInt8, body: Data) -> Data {
        var result = Data([tag])
        if body.count < 128 {
            result.append(UInt8(body.count))
        } else if body.count < 256 {
            result.append(0x81)
            result.append(UInt8(body.count))
        } else {
            result.append(0x82)
            result.append(UInt8(body.count >> 8))
            result.append(UInt8(body.count & 0xff))
        }
        result.append(body)
        return result
    }

    private struct DERCursor {
        let data: Data
        var index: Int

        mutating func tlv() -> (tag: UInt8, body: Data)? {
            guard index < data.count else { return nil }
            let tag = data[index]
            index += 1
            guard index < data.count else { return nil }
            let first = data[index]
            index += 1
            let length: Int
            if first < 0x80 {
                length = Int(first)
            } else {
                let count = Int(first & 0x7f)
                guard count > 0, count <= 3, index + count <= data.count else { return nil }
                var value = 0
                for _ in 0..<count {
                    value = (value << 8) | Int(data[index])
                    index += 1
                }
                length = value
            }
            guard index + length <= data.count else { return nil }
            let body = data.subdata(in: index..<(index + length))
            index += length
            return (tag, body)
        }
    }
}

private extension Data {
    init?(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count % 2 == 0 else { return nil }
        var data = Data()
        data.reserveCapacity(cleaned.count / 2)
        var index = cleaned.startIndex
        while index < cleaned.endIndex {
            let next = cleaned.index(index, offsetBy: 2)
            guard let byte = UInt8(cleaned[index..<next], radix: 16) else { return nil }
            data.append(byte)
            index = next
        }
        self = data
    }
}
