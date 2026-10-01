import Foundation
import Security

public enum PasswordGenerator {
    public static let words: [String] = {
        let raw = """
        apple river stone cloud maple cedar birch pine oak willow coral amber frost ember
        canyon meadow harbor lighthouse pebble lantern meadowlark sparrow falcon otter
        willowbark copper bronze silver marble granite basalt quartz ambergris sail
        compass anchor voyage island lagoon glacier summit valley orchard vineyard
        kettle lanternbook notebook pencil paper ink quill canvas brush color melody
        rhythm violin cello flute drum trumpet piano harvest autumn winter spring
        summer thunder lightning breeze horizon sunrise sunset twilight midnight
        orange lemon mango berry plum peach apricot cherry walnut almond cashew
        pepper cinnamon ginger vanilla cocoa coffee tea honey maplewood cabin
        trail ridge forest riverbank dock pier buoy kelp dune cactus juniper
        heron crane robin wren badger beaver fox hare moose elk bison
        north south east west atlas globe compassrose lanternlight cobble brick
        window garden terrace patio kitchen hearth chimney roof timber plank
        """
        var seen = Set<String>()
        return raw.split(whereSeparator: \.isWhitespace).map(String.init).filter { seen.insert($0).inserted }
    }()

    public static func entropy(
        passphrase: Bool,
        length: Int,
        wordCount: Int,
        lowercase: Bool,
        uppercase: Bool,
        digits: Bool,
        symbols: Bool,
        excludeAmbiguous: Bool
    ) -> Double {
        if passphrase {
            guard words.count > 1, wordCount > 0 else { return 0 }
            return Double(wordCount) * log2(Double(words.count))
        }
        let pool = poolCharacters(
            lowercase: lowercase,
            uppercase: uppercase,
            digits: digits,
            symbols: symbols,
            excludeAmbiguous: excludeAmbiguous
        ).count
        guard pool > 1, length > 0 else { return 0 }
        return Double(length) * log2(Double(pool))
    }

    public static func generate(
        passphrase: Bool,
        length: Int,
        wordCount: Int,
        lowercase: Bool,
        uppercase: Bool,
        digits: Bool,
        symbols: Bool,
        excludeAmbiguous: Bool,
        separator: String,
        capitalize: Bool
    ) -> ToolResult {
        let bits = entropy(
            passphrase: passphrase,
            length: length,
            wordCount: wordCount,
            lowercase: lowercase,
            uppercase: uppercase,
            digits: digits,
            symbols: symbols,
            excludeAmbiguous: excludeAmbiguous
        )
        let secret: String
        if passphrase {
            guard (3...16).contains(wordCount) else { return .failure("Passphrase length must be 3 to 16 words.") }
            guard let picked = pickWords(count: wordCount, separator: separator, capitalize: capitalize) else {
                return .failure("Could not read random bytes.")
            }
            secret = picked
        } else {
            guard (4...256).contains(length) else { return .failure("Password length must be 4 to 256.") }
            let pool = poolCharacters(
                lowercase: lowercase,
                uppercase: uppercase,
                digits: digits,
                symbols: symbols,
                excludeAmbiguous: excludeAmbiguous
            )
            if pool.isEmpty { return .failure("Choose at least one character set.") }
            guard let picked = pickCharacters(pool: pool, length: length) else {
                return .failure("Could not read random bytes.")
            }
            secret = picked
        }
        return .success("\(secret)\nEntropy: \(String(format: "%.1f", bits)) bits (\(strength(bits)))")
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        let result = generate(
            passphrase: false,
            length: 20,
            wordCount: 4,
            lowercase: true,
            uppercase: true,
            digits: true,
            symbols: false,
            excludeAmbiguous: true,
            separator: "-",
            capitalize: false
        )
        let line = result.output.split(separator: "\n").first.map(String.init) ?? ""
        let allowed = poolCharacters(lowercase: true, uppercase: true, digits: true, symbols: false, excludeAmbiguous: true)
        expect("password length", result.issue == nil && line.count == 20)
        expect("password charset", line.allSatisfy { allowed.contains($0) })
        expect("password no ambiguous", !line.contains(where: { "0O1lI|".contains($0) }))
        expect("password entropy", result.output.contains("bits"))
        let phrase = generate(
            passphrase: true,
            length: 12,
            wordCount: 4,
            lowercase: true,
            uppercase: false,
            digits: false,
            symbols: false,
            excludeAmbiguous: false,
            separator: "-",
            capitalize: false
        )
        let wordsOut = phrase.output.split(separator: "\n").first.map(String.init)?.split(separator: "-").map(String.init) ?? []
        expect("passphrase words", wordsOut.count == 4 && wordsOut.allSatisfy { words.contains($0) })
        expect("password empty sets", generate(
            passphrase: false, length: 12, wordCount: 4,
            lowercase: false, uppercase: false, digits: false, symbols: false,
            excludeAmbiguous: false, separator: " ", capitalize: false
        ).issue != nil)
        expect("password bad length", generate(
            passphrase: false, length: 2, wordCount: 4,
            lowercase: true, uppercase: false, digits: false, symbols: false,
            excludeAmbiguous: false, separator: " ", capitalize: false
        ).issue != nil)
    }

    public static func poolCharacters(
        lowercase: Bool,
        uppercase: Bool,
        digits: Bool,
        symbols: Bool,
        excludeAmbiguous: Bool
    ) -> [Character] {
        var pool = ""
        if lowercase { pool += "abcdefghijklmnopqrstuvwxyz" }
        if uppercase { pool += "ABCDEFGHIJKLMNOPQRSTUVWXYZ" }
        if digits { pool += "0123456789" }
        if symbols { pool += "!@#$%^&*()-_=+[]{};:,.?/" }
        if excludeAmbiguous {
            pool.removeAll { "0O1lI|".contains($0) }
        }
        return Array(pool)
    }

    private static func pickCharacters(pool: [Character], length: Int) -> String? {
        let limit = 256 - (256 % pool.count)
        var output = ""
        var spins = 0
        while output.count < length {
            spins += 1
            if spins > length * 8 { return nil }
            guard let bytes = randomBytes(max(length, 16)) else { return nil }
            for byte in bytes where output.count < length {
                if Int(byte) < limit {
                    output.append(pool[Int(byte) % pool.count])
                }
            }
        }
        return output
    }

    private static func pickWords(count: Int, separator: String, capitalize: Bool) -> String? {
        var chosen: [String] = []
        let limit = 256 - (256 % words.count)
        var spins = 0
        while chosen.count < count {
            spins += 1
            if spins > count * 8 { return nil }
            guard let bytes = randomBytes(max(count * 2, 16)) else { return nil }
            for byte in bytes where chosen.count < count {
                if Int(byte) < limit {
                    var word = words[Int(byte) % words.count]
                    if capitalize, let first = word.first {
                        word.replaceSubrange(word.startIndex...word.startIndex, with: String(first).uppercased())
                    }
                    chosen.append(word)
                }
            }
        }
        return chosen.joined(separator: separator)
    }

    private static func strength(_ bits: Double) -> String {
        if bits < 40 { return "weak" }
        if bits < 60 { return "fair" }
        if bits < 80 { return "strong" }
        return "very strong"
    }

    private static func randomBytes(_ count: Int) -> [UInt8]? {
        var bytes = [UInt8](repeating: 0, count: count)
        guard SecRandomCopyBytes(kSecRandomDefault, count, &bytes) == errSecSuccess else { return nil }
        return bytes
    }
}
