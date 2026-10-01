import Foundation

public enum URLTextEncoder {
    public enum Scope: String, Sendable {
        case component, fullURL
    }

    public enum Direction: String, Sendable {
        case encode, decode
    }

    public static func convert(_ text: String, direction: Direction, scope: Scope) -> ToolResult {
        if let issue = InputChecks.issue(for: text, emptyPrompt: direction == .encode ? "Enter text to encode." : "Enter a percent-encoded string to decode.") {
            return .failure(issue)
        }
        switch direction {
        case .encode:
            let allowed = scope == .component ? componentAllowed : fullURLAllowed
            guard let encoded = text.addingPercentEncoding(withAllowedCharacters: allowed) else {
                return .failure("Could not percent-encode this text.")
            }
            return .success(encoded)
        case .decode:
            guard let decoded = text.removingPercentEncoding else {
                return .failure("Could not percent-decode this text.")
            }
            return .success(decoded)
        }
    }

    private static let componentAllowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    private static let fullURLAllowed: CharacterSet = {
        var set = CharacterSet.urlUserAllowed
        set.formUnion(.urlHostAllowed)
        set.formUnion(.urlPathAllowed)
        set.formUnion(.urlQueryAllowed)
        set.formUnion(.urlFragmentAllowed)
        set.formUnion(CharacterSet(charactersIn: "#"))
        return set
    }()
}
