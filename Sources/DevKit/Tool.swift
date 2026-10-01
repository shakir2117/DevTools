import SwiftUI

enum ToolCategory: String, CaseIterable, Identifiable {
    case formatters
    case converters
    case encoders
    case inspection
    case generators
    case networking

    var id: String { rawValue }

    var title: String {
        switch self {
        case .formatters: return "Formatters"
        case .converters: return "Converters"
        case .encoders: return "Encoders"
        case .inspection: return "Inspection"
        case .generators: return "Generators"
        case .networking: return "Networking"
        }
    }

    var symbol: String {
        switch self {
        case .formatters: return "text.alignleft"
        case .converters: return "arrow.left.arrow.right"
        case .encoders: return "lock"
        case .inspection: return "magnifyingglass"
        case .generators: return "sparkles"
        case .networking: return "network"
        }
    }

    var tint: Color {
        switch self {
        case .formatters: return .blue
        case .converters: return .orange
        case .encoders: return .purple
        case .inspection: return .teal
        case .generators: return .pink
        case .networking: return .green
        }
    }

    var blurb: String {
        switch self {
        case .formatters: return "Pretty-print code, markup, data, and queries."
        case .converters: return "Turn one format into another."
        case .encoders: return "Encode, decode, hash, and generate values."
        case .inspection: return "Read, check, and explain data you already have."
        case .generators: return "Build files, codes, and schedules."
        case .networking: return "Call a host and inspect DNS, TLS, and HTTP."
        }
    }
}

protocol Tool: Identifiable where ID == String {
    var id: String { get }
    var name: String { get }
    var summary: String { get }
    var symbol: String { get }
    var category: ToolCategory { get }
    func makeView() -> AnyView
}
