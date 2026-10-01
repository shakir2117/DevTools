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
}

protocol Tool: Identifiable where ID == String {
    var id: String { get }
    var name: String { get }
    var summary: String { get }
    var symbol: String { get }
    var category: ToolCategory { get }
    func makeView() -> AnyView
}
