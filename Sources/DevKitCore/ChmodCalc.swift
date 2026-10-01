import Foundation

public enum ChmodCalc {
    public static func explain(_ text: String) -> ToolResult {
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return .success("") }
        if raw.utf8.contains(0) || raw.contains("\n") { return .failure("Enter one mode, such as 755 or rwxr-xr-x.") }
        let mode: Int
        if let parsed = octal(raw) {
            mode = parsed
        } else if let parsed = symbolic(raw) {
            mode = parsed
        } else {
            return .failure("Enter an octal mode such as 755, or a symbolic mode such as rwxr-xr-x.")
        }
        let special = mode >> 9
        let owner = (mode >> 6) & 7
        let group = (mode >> 3) & 7
        let other = mode & 7
        let lines = [
            String(format: "Octal: %04o", mode),
            "Symbolic: \(symbols(mode))",
            "Owner: \(rights(owner))",
            "Group: \(rights(group))",
            "Other: \(rights(other))",
            "Special: \(specialText(special))",
        ]
        return .success(lines.joined(separator: "\n"))
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        let plain = explain("755")
        expect("chmod 755", plain.output.contains("0755") && plain.output.contains("rwxr-xr-x"))
        let setuid = explain("4755")
        expect("chmod setuid", setuid.output.contains("rwsr-xr-x") && setuid.output.contains("setuid"))
        expect("chmod back", explain("rwxr-xr-x").output.contains("0755"))
        expect("chmod sticky", explain("1755").output.contains("rwxr-xr-t"))
        expect("chmod bad", explain("-rwx").issue != nil)
    }

    private static func octal(_ text: String) -> Int? {
        guard (3...4).contains(text.count), text.allSatisfy({ $0.isNumber }), let value = Int(text, radix: 8), value <= 0o7777 else { return nil }
        return value
    }

    private static func symbolic(_ text: String) -> Int? {
        guard text.count == 9 else { return nil }
        let chars = Array(text)
        var mode = 0
        for (offset, triad) in stride(from: 0, to: 9, by: 3).enumerated() {
            let read = chars[triad]
            let write = chars[triad + 1]
            let execute = chars[triad + 2]
            if read == "r" { mode |= 4 << (6 - offset * 3) } else if read != "-" { return nil }
            if write == "w" { mode |= 2 << (6 - offset * 3) } else if write != "-" { return nil }
            switch execute {
            case "x": mode |= 1 << (6 - offset * 3)
            case "-": break
            case "s", "S":
                if offset == 0 { mode |= 0o4000 } else if offset == 1 { mode |= 0o2000 } else { return nil }
                if execute == "s" { mode |= 1 << (6 - offset * 3) }
            case "t", "T":
                if offset != 2 { return nil }
                mode |= 0o1000
                if execute == "t" { mode |= 1 }
            default: return nil
            }
        }
        return mode
    }

    private static func symbols(_ mode: Int) -> String {
        var text = ""
        text += triad((mode >> 6) & 7, special: (mode & 0o4000) != 0 ? "s" : nil)
        text += triad((mode >> 3) & 7, special: (mode & 0o2000) != 0 ? "s" : nil)
        text += triad(mode & 7, special: (mode & 0o1000) != 0 ? "t" : nil)
        return text
    }

    private static func triad(_ bits: Int, special: Character?) -> String {
        var text = ""
        text.append((bits & 4) != 0 ? "r" : "-")
        text.append((bits & 2) != 0 ? "w" : "-")
        if let special {
            let execute = (bits & 1) != 0
            if special == "t" { text.append(execute ? "t" : "T") } else { text.append(execute ? "s" : "S") }
        } else {
            text.append((bits & 1) != 0 ? "x" : "-")
        }
        return text
    }

    private static func rights(_ bits: Int) -> String {
        var names: [String] = []
        if (bits & 4) != 0 { names.append("read") }
        if (bits & 2) != 0 { names.append("write") }
        if (bits & 1) != 0 { names.append("execute") }
        return names.isEmpty ? "none" : names.joined(separator: ", ")
    }

    private static func specialText(_ bits: Int) -> String {
        var names: [String] = []
        if (bits & 4) != 0 { names.append("setuid") }
        if (bits & 2) != 0 { names.append("setgid") }
        if (bits & 1) != 0 { names.append("sticky") }
        return names.isEmpty ? "none" : names.joined(separator: ", ")
    }
}
