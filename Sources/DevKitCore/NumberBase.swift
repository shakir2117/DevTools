import Foundation

public enum NumberBase {
    public static func convert(_ text: String, from: Int, to: Int, uppercase: Bool = false) -> ToolResult {
        guard (2...36).contains(from), (2...36).contains(to) else {
            return .failure("Bases must be from 2 to 36.")
        }
        if text.count > 100_000 {
            return .failure("This number is longer than 100,000 digits.")
        }
        if let issue = InputChecks.issue(for: text, emptyPrompt: "Enter a number to convert.") {
            return .failure(issue)
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var sign = ""
        var body = trimmed
        if body.hasPrefix("-") {
            sign = "-"
            body = String(body.dropFirst())
        } else if body.hasPrefix("+") {
            body = String(body.dropFirst())
        }
        let lowered = body.lowercased()
        if from == 16, lowered.hasPrefix("0x") { body = String(body.dropFirst(2)) }
        if from == 2, lowered.hasPrefix("0b") { body = String(body.dropFirst(2)) }
        if from == 8, lowered.hasPrefix("0o") { body = String(body.dropFirst(2)) }
        var digits = ""
        var column = 1
        for character in body {
            if character == "_" || character == " " || character == "\n" {
                column += 1
                continue
            }
            guard let value = digitValue(character), value < from else {
                return .failure("Digit \"\(character)\" is not valid in base \(from).", column: column)
            }
            digits.append(character)
            column += 1
        }
        if digits.isEmpty {
            return .failure("Enter a number to convert.")
        }
        var magnitude = Magnitude()
        for character in digits {
            guard let value = digitValue(character) else {
                return .failure("Digit \"\(character)\" is not valid in base \(from).")
            }
            magnitude.multiply(by: UInt32(from))
            magnitude.add(UInt32(value))
        }
        var rendered = magnitude.render(base: to)
        if uppercase { rendered = rendered.uppercased() }
        if magnitude.isZero { sign = "" }
        return .success(sign + rendered)
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        let hex = convert("255", from: 10, to: 16)
        expect("base 255 hex", hex.output == "ff")
        let bin = convert("ff", from: 16, to: 2)
        expect("base ff bin", bin.output == "11111111")
        let back = convert("11111111", from: 2, to: 10)
        expect("base bin decimal", back.output == "255")
        let prefixed = convert("0xFF", from: 16, to: 10, uppercase: false)
        expect("base prefix", prefixed.output == "255")
        let big = "123456789012345678901234567890"
        let via = convert(convert(big, from: 10, to: 36).output, from: 36, to: 10)
        expect("base roundtrip", via.output == big && via.issue == nil)
        let negative = convert("-10", from: 10, to: 2)
        expect("base negative", negative.output == "-1010")
        let bad = convert("12G", from: 16, to: 10)
        expect("base bad digit", bad.issue?.column == 3)
        expect("base empty", convert("  ", from: 10, to: 2).issue != nil)
        expect("base binary junk", convert(String(repeating: "\u{0}", count: 4), from: 10, to: 16).issue != nil)
    }

    private static func digitValue(_ character: Character) -> Int? {
        guard let scalar = character.unicodeScalars.first, character.unicodeScalars.count == 1 else { return nil }
        let value = scalar.value
        if value >= 48 && value <= 57 { return Int(value - 48) }
        if value >= 65 && value <= 90 { return Int(value - 65) + 10 }
        if value >= 97 && value <= 122 { return Int(value - 97) + 10 }
        return nil
    }

    private struct Magnitude {
        private var limbs: [UInt32] = []

        var isZero: Bool { limbs.allSatisfy { $0 == 0 } }

        mutating func multiply(by factor: UInt32) {
            if limbs.isEmpty { return }
            var carry: UInt64 = 0
            for index in 0..<limbs.count {
                let product = UInt64(limbs[index]) * UInt64(factor) + carry
                limbs[index] = UInt32(truncatingIfNeeded: product)
                carry = product >> 32
            }
            if carry > 0 {
                limbs.append(UInt32(truncatingIfNeeded: carry))
            }
        }

        mutating func add(_ value: UInt32) {
            var carry = UInt64(value)
            var index = 0
            while carry > 0 {
                if index == limbs.count {
                    limbs.append(0)
                }
                let sum = UInt64(limbs[index]) + carry
                limbs[index] = UInt32(truncatingIfNeeded: sum)
                carry = sum >> 32
                index += 1
            }
        }

        func render(base: Int) -> String {
            if isZero || limbs.isEmpty { return "0" }
            var value = self
            value.trim()
            var digits: [Character] = []
            let divisor = UInt32(base)
            while !value.isZero {
                let remainder = value.divide(by: divisor)
                digits.append(digitCharacter(Int(remainder)))
            }
            return String(digits.reversed())
        }

        private mutating func divide(by divisor: UInt32) -> UInt32 {
            var remainder: UInt64 = 0
            for index in stride(from: limbs.count - 1, through: 0, by: -1) {
                let current = (remainder << 32) | UInt64(limbs[index])
                limbs[index] = UInt32(current / UInt64(divisor))
                remainder = current % UInt64(divisor)
            }
            trim()
            return UInt32(remainder)
        }

        private mutating func trim() {
            while limbs.last == 0 { limbs.removeLast() }
        }

        private func digitCharacter(_ value: Int) -> Character {
            let alphabet = Array("0123456789abcdefghijklmnopqrstuvwxyz")
            guard value >= 0, value < alphabet.count else { return "?" }
            return alphabet[value]
        }
    }
}
