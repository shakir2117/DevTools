import Foundation
import Security

public enum IDGenerator {
    public enum Kind: String, CaseIterable, Sendable {
        case uuidV4, uuidV7, ulid, nanoID

        public var title: String {
            switch self {
            case .uuidV4: return "UUID v4"
            case .uuidV7: return "UUID v7"
            case .ulid: return "ULID"
            case .nanoID: return "NanoID"
            }
        }
    }

    public static let nanoAlphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_-"
    private static let crockford = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")

    public static func generate(
        kind: Kind,
        count: Int,
        uppercase: Bool,
        hyphens: Bool,
        nanoLength: Int,
        date: Date = Date(),
        random: [UInt8]? = nil
    ) -> ToolResult {
        guard (1...1000).contains(count) else {
            return .failure("Count must be from 1 to 1000.")
        }
        if kind == .nanoID, !(1...128).contains(nanoLength) {
            return .failure("NanoID length must be from 1 to 128.")
        }
        var lines: [String] = []
        lines.reserveCapacity(count)
        for _ in 0..<count {
            switch kind {
            case .uuidV4:
                guard let bytes = random.map({ Array($0.prefix(16)) }) ?? randomBytes(16), bytes.count == 16 else {
                    return .failure("Could not read random bytes.")
                }
                lines.append(formatUUID(version4(bytes), hyphens: hyphens, uppercase: uppercase))
            case .uuidV7:
                guard let bytes = random.map({ Array($0.prefix(16)) }) ?? randomBytes(16), bytes.count == 16 else {
                    return .failure("Could not read random bytes.")
                }
                lines.append(formatUUID(version7(bytes, date: date), hyphens: hyphens, uppercase: uppercase))
            case .ulid:
                guard let bytes = random.map({ Array($0.prefix(10)) }) ?? randomBytes(10), bytes.count == 10 else {
                    return .failure("Could not read random bytes.")
                }
                let text = ulid(date: date, random: bytes)
                lines.append(uppercase ? text : text.lowercased())
            case .nanoID:
                guard let text = nanoID(length: nanoLength) else {
                    return .failure("Could not read random bytes.")
                }
                lines.append(text)
            }
        }
        return .success(lines.joined(separator: "\n"))
    }

    public static func ulid(date: Date, random: [UInt8]) -> String {
        let ms = UInt64(max(0, date.timeIntervalSince1970 * 1000))
        return encodeTime(ms) + encodeBits(random)
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        let v4 = generate(kind: .uuidV4, count: 2, uppercase: false, hyphens: true, nanoLength: 21, random: Array(repeating: 0, count: 16))
        let v4lines = v4.output.split(separator: "\n")
        expect("uuid v4 shape", v4.issue == nil && v4lines.count == 2 && v4lines[0].count == 36)
        expect("uuid v4 version", v4lines.first?.dropFirst(14).first == "4")
        expect("uuid v4 variant", v4lines.first?.dropFirst(19).first.map { "89ab".contains($0) } == true)

        let v7 = generate(kind: .uuidV7, count: 1, uppercase: true, hyphens: false, nanoLength: 21, date: Date(timeIntervalSince1970: 0), random: Array(repeating: 0, count: 16))
        expect("uuid v7 compact", v7.output.count == 32 && v7.output.allSatisfy { $0.isHexDigit })
        expect("uuid v7 version nibble", v7.output.dropFirst(12).first == "7")

        let ulidText = ulid(date: Date(timeIntervalSince1970: 0), random: Array(repeating: 0, count: 10))
        expect("ulid epoch", ulidText == String(repeating: "0", count: 26))

        let nano = generate(kind: .nanoID, count: 3, uppercase: false, hyphens: true, nanoLength: 12)
        let nanoLines = nano.output.split(separator: "\n")
        expect("nanoid length", nano.issue == nil && nanoLines.count == 3 && nanoLines.allSatisfy { $0.count == 12 })
        expect("nanoid alphabet", nanoLines.allSatisfy { line in line.allSatisfy { nanoAlphabet.contains($0) } })
        expect("id count rejected", generate(kind: .uuidV4, count: 0, uppercase: false, hyphens: true, nanoLength: 21).issue != nil)
        expect("id huge count rejected", generate(kind: .ulid, count: 5000, uppercase: false, hyphens: true, nanoLength: 21).issue != nil)
    }

    private static func version4(_ bytes: [UInt8]) -> [UInt8] {
        var copy = bytes
        copy[6] = (copy[6] & 0x0f) | 0x40
        copy[8] = (copy[8] & 0x3f) | 0x80
        return copy
    }

    private static func version7(_ bytes: [UInt8], date: Date) -> [UInt8] {
        var copy = bytes
        let ms = UInt64(max(0, date.timeIntervalSince1970 * 1000))
        copy[0] = UInt8((ms >> 40) & 0xff)
        copy[1] = UInt8((ms >> 32) & 0xff)
        copy[2] = UInt8((ms >> 24) & 0xff)
        copy[3] = UInt8((ms >> 16) & 0xff)
        copy[4] = UInt8((ms >> 8) & 0xff)
        copy[5] = UInt8(ms & 0xff)
        copy[6] = (copy[6] & 0x0f) | 0x70
        copy[8] = (copy[8] & 0x3f) | 0x80
        return copy
    }

    private static func formatUUID(_ bytes: [UInt8], hyphens: Bool, uppercase: Bool) -> String {
        let hex = bytes.map { String(format: "%02x", $0) }.joined()
        let text: String
        if hyphens {
            let chars = Array(hex)
            text = "\(String(chars[0..<8]))-\(String(chars[8..<12]))-\(String(chars[12..<16]))-\(String(chars[16..<20]))-\(String(chars[20..<32]))"
        } else {
            text = hex
        }
        return uppercase ? text.uppercased() : text
    }

    private static func encodeTime(_ ms: UInt64) -> String {
        var value = ms
        var chars: [Character] = []
        chars.reserveCapacity(10)
        for _ in 0..<10 {
            chars.append(crockford[Int(value % 32)])
            value /= 32
        }
        return String(chars.reversed())
    }

    private static func encodeBits(_ bytes: [UInt8]) -> String {
        var buffer: UInt16 = 0
        var count = 0
        var output = ""
        for byte in bytes {
            buffer = (buffer << 8) | UInt16(byte)
            count += 8
            while count >= 5 {
                count -= 5
                let index = Int((buffer >> count) & 31)
                output.append(crockford[index])
            }
        }
        return output
    }

    private static func nanoID(length: Int) -> String? {
        let alphabet = Array(nanoAlphabet)
        let limit = 256 - (256 % alphabet.count)
        var output = ""
        output.reserveCapacity(length)
        var guardrail = 0
        while output.count < length {
            guardrail += 1
            if guardrail > length * 20 { return nil }
            guard let bytes = randomBytes(max(length, 16)) else { return nil }
            for byte in bytes where output.count < length {
                if Int(byte) < limit {
                    output.append(alphabet[Int(byte) % alphabet.count])
                }
            }
        }
        return output
    }

    private static func randomBytes(_ count: Int) -> [UInt8]? {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        guard status == errSecSuccess else { return nil }
        return bytes
    }
}
