import Foundation

public enum SnowflakeID {
    public enum Kind: String {
        case twitter
        case discord

        var epoch: UInt64 {
            switch self {
            case .twitter: return 1_288_834_974_657
            case .discord: return 1_420_070_400_000
            }
        }
    }

    public static func decode(_ text: String, kind: Kind) -> ToolResult {
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return .success("") }
        if raw.hasPrefix("-") || raw.contains("\n") || !raw.allSatisfy(\.isNumber) {
            return .failure("Enter a positive snowflake id.")
        }
        guard let id = UInt64(raw) else { return .failure("That id does not fit in 64 bits.") }
        return .success(report(id, kind: kind))
    }

    public static func encode(milliseconds: UInt64, worker: Int, process: Int, sequence: Int, kind: Kind) -> ToolResult {
        guard milliseconds >= kind.epoch else { return .failure("That time is before the \(kind.rawValue) epoch.") }
        guard (0...31).contains(worker), (0...31).contains(process), (0...4095).contains(sequence) else {
            return .failure("Worker and process are 0...31, and sequence is 0...4095.")
        }
        let delta = milliseconds - kind.epoch
        if delta >= (1 << 41) { return .failure("That time does not fit in a snowflake.") }
        let id = (delta << 22) | (UInt64(worker) << 17) | (UInt64(process) << 12) | UInt64(sequence)
        return .success(report(id, kind: kind))
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        let made = encode(milliseconds: 1_600_000_000_000, worker: 1, process: 2, sequence: 7, kind: .twitter)
        expect("snow time", made.output.contains("2020-"))
        expect("snow worker", made.output.contains("Worker: 1") && made.output.contains("Process: 2") && made.output.contains("Sequence: 7"))
        let line = made.output.split(separator: "\n").first.map(String.init) ?? ""
        let id = line.replacingOccurrences(of: "ID: ", with: "")
        expect("snow round", decode(id, kind: .twitter).output.contains("Sequence: 7"))
        expect("snow dash", decode("-1", kind: .discord).issue != nil)
    }

    private static func report(_ id: UInt64, kind: Kind) -> String {
        let delta = id >> 22
        let worker = Int((id >> 17) & 0b1_1111)
        let process = Int((id >> 12) & 0b1_1111)
        let sequence = Int(id & 0xFFF)
        let milliseconds = kind.epoch + delta
        let date = Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return [
            "ID: \(id)",
            "Layout: \(kind.rawValue)",
            "Time: \(formatter.string(from: date))",
            "Worker: \(worker)",
            "Process: \(process)",
            "Sequence: \(sequence)",
        ].joined(separator: "\n")
    }
}
