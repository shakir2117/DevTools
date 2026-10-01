import Foundation

public enum UnitConvert {
    public struct Family: Identifiable, Sendable {
        public var id: String
        public var title: String
        public var units: [String]
    }

    public static let families: [Family] = [
        Family(id: "length", title: "Length", units: ["mm", "cm", "m", "km", "in", "ft", "yd", "mi"]),
        Family(id: "mass", title: "Mass", units: ["mg", "g", "kg", "oz", "lb"]),
        Family(id: "temperature", title: "Temperature", units: ["C", "F", "K"]),
        Family(id: "volume", title: "Volume", units: ["ml", "l", "tsp", "tbsp", "cup", "floz", "pt", "qt", "gal"]),
        Family(id: "area", title: "Area", units: ["mm2", "cm2", "m2", "km2", "in2", "ft2", "acre"]),
        Family(id: "speed", title: "Speed", units: ["m/s", "km/h", "mph", "kn"]),
        Family(id: "time", title: "Time", units: ["ns", "us", "ms", "s", "min", "h", "day"]),
        Family(id: "data", title: "Data", units: ["B", "KB", "MB", "GB", "TB", "KiB", "MiB", "GiB", "TiB"]),
        Family(id: "energy", title: "Energy", units: ["J", "kJ", "cal", "kcal", "Wh", "kWh"]),
        Family(id: "pressure", title: "Pressure", units: ["Pa", "kPa", "bar", "psi", "atm"]),
    ]

    public static func convert(text: String, family: String, from: String, to: String) -> ToolResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .failure("Enter a number to convert.") }
        if trimmed.count > 100 { return .failure("That number is too long.") }
        guard let value = Double(trimmed), value.isFinite else { return .failure("Enter a finite number.") }
        guard let group = families.first(where: { $0.id == family }) else { return .failure("Unknown unit family.") }
        guard group.units.contains(from), group.units.contains(to) else { return .failure("Those units are not in \(group.title).") }
        let result = convert(value, family: family, from: from, to: to)
        return .success(format(result) + " \(to)")
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        expect("unit km", convert(text: "1", family: "length", from: "km", to: "m").output == "1000 m")
        expect("unit temp", convert(text: "0", family: "temperature", from: "C", to: "F").output == "32 F")
        expect("unit temp k", abs((Double(convert(text: "100", family: "temperature", from: "C", to: "K").output.split(separator: " ").first ?? "0") ?? 0) - 373.15) < 0.01)
        let round = convert(text: "12.5", family: "mass", from: "kg", to: "lb")
        let back = convert(text: round.output.split(separator: " ").first.map(String.init) ?? "", family: "mass", from: "lb", to: "kg")
        let backValue = Double(back.output.split(separator: " ").first ?? "0") ?? 0
        expect("unit roundtrip", abs(backValue - 12.5) < 0.001)
        expect("unit data", convert(text: "1", family: "data", from: "KiB", to: "B").output == "1024 B")
        expect("unit empty", convert(text: " ", family: "length", from: "m", to: "km").issue != nil)
        expect("unit bad", convert(text: "abc", family: "time", from: "s", to: "ms").issue != nil)
    }

    private static func convert(_ value: Double, family: String, from: String, to: String) -> Double {
        if family == "temperature" {
            return fromKelvin(toKelvin(value, from), to)
        }
        let base = value * factor(family, from)
        return base / factor(family, to)
    }

    private static func factor(_ family: String, _ unit: String) -> Double {
        let table: [String: Double]
        switch family {
        case "length":
            table = ["mm": 0.001, "cm": 0.01, "m": 1, "km": 1000, "in": 0.0254, "ft": 0.3048, "yd": 0.9144, "mi": 1609.344]
        case "mass":
            table = ["mg": 0.000001, "g": 0.001, "kg": 1, "oz": 0.028349523125, "lb": 0.45359237]
        case "volume":
            table = ["ml": 0.001, "l": 1, "tsp": 0.00492892159375, "tbsp": 0.01478676478125, "cup": 0.2365882365, "floz": 0.0295735295625, "pt": 0.473176473, "qt": 0.946352946, "gal": 3.785411784]
        case "area":
            table = ["mm2": 0.000001, "cm2": 0.0001, "m2": 1, "km2": 1_000_000, "in2": 0.00064516, "ft2": 0.09290304, "acre": 4046.8564224]
        case "speed":
            table = ["m/s": 1, "km/h": 1 / 3.6, "mph": 0.44704, "kn": 0.514444]
        case "time":
            table = ["ns": 1e-9, "us": 1e-6, "ms": 0.001, "s": 1, "min": 60, "h": 3600, "day": 86400]
        case "data":
            table = ["B": 1, "KB": 1000, "MB": 1e6, "GB": 1e9, "TB": 1e12, "KiB": 1024, "MiB": 1_048_576, "GiB": 1_073_741_824, "TiB": 1_099_511_627_776]
        case "energy":
            table = ["J": 1, "kJ": 1000, "cal": 4.184, "kcal": 4184, "Wh": 3600, "kWh": 3_600_000]
        case "pressure":
            table = ["Pa": 1, "kPa": 1000, "bar": 100_000, "psi": 6894.757293168, "atm": 101_325]
        default:
            table = [:]
        }
        return table[unit] ?? 1
    }

    private static func toKelvin(_ value: Double, _ unit: String) -> Double {
        switch unit {
        case "C": return value + 273.15
        case "F": return (value - 32) * 5 / 9 + 273.15
        default: return value
        }
    }

    private static func fromKelvin(_ value: Double, _ unit: String) -> Double {
        switch unit {
        case "C": return value - 273.15
        case "F": return (value - 273.15) * 9 / 5 + 32
        default: return value
        }
    }

    private static func format(_ value: Double) -> String {
        if value.rounded() == value, abs(value) < 1e15 { return String(format: "%.0f", value) }
        let text = String(format: "%.8f", value)
        var trimmed = text
        while trimmed.contains("."), trimmed.last == "0" { trimmed.removeLast() }
        if trimmed.last == "." { trimmed.removeLast() }
        return trimmed
    }
}
