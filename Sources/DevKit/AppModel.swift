import Foundation
import SwiftUI

struct ToolBlob: Codable, Equatable {
    var input: String?
    var options: String?
}

final class AppModel: ObservableObject {
    @Published var selectedToolID: String?
    @Published var favorites: [String] = []
    @Published var recent: [String] = []
    @Published var search = ""
    @Published var paletteOpen = false
    @Published var copyRequest = 0
    @Published var sampleRequest = 0
    @Published var notice: String?
    @Published private var blobs: [String: ToolBlob] = [:]

    private let defaults = UserDefaults.standard
    private let lastKey = "devkit.lastTool"
    private let favoritesKey = "devkit.favorites"
    private let recentKey = "devkit.recent"
    private let stateKey = "devkit.toolState"
    private var noticeTick = 0

    init() {
        selectedToolID = defaults.string(forKey: lastKey)
        favorites = defaults.stringArray(forKey: favoritesKey) ?? []
        recent = defaults.stringArray(forKey: recentKey) ?? []
        if let data = defaults.data(forKey: stateKey),
           let decoded = try? JSONDecoder().decode([String: ToolBlob].self, from: data) {
            blobs = decoded
        }
    }

    func requestSample() {
        sampleRequest += 1
    }

    func select(_ id: String?) {
        selectedToolID = id
        if let id {
            defaults.set(id, forKey: lastKey)
            recent.removeAll { $0 == id }
            recent.insert(id, at: 0)
            if recent.count > 8 { recent = Array(recent.prefix(8)) }
            defaults.set(recent, forKey: recentKey)
        } else {
            defaults.removeObject(forKey: lastKey)
        }
    }

    func isFavorite(_ id: String) -> Bool {
        favorites.contains(id)
    }

    func toggleFavorite(_ id: String) {
        if let index = favorites.firstIndex(of: id) {
            favorites.remove(at: index)
        } else {
            favorites.append(id)
        }
        defaults.set(favorites, forKey: favoritesKey)
    }

    func requestCopyOutput() {
        copyRequest += 1
    }

    func flash(_ message: String) {
        notice = message
        noticeTick += 1
        let tick = noticeTick
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            guard let self, self.noticeTick == tick else { return }
            self.notice = nil
        }
    }

    func blob(for id: String) -> ToolBlob {
        blobs[id] ?? ToolBlob()
    }

    func setInput(_ text: String?, for id: String) {
        var blob = blobs[id] ?? ToolBlob()
        if let text, text.count <= 200_000 {
            blob.input = text
        } else {
            blob.input = nil
        }
        blobs[id] = blob
        persistBlobs()
    }

    func loadOptionsObject(for id: String) -> [String: Any] {
        guard let raw = blob(for: id).options,
              let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return object
    }

    func saveOptionsObject(_ object: [String: Any], for id: String) {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object),
              let json = String(data: data, encoding: .utf8) else { return }
        setOptions(json, for: id)
    }

    func setOptions(_ json: String?, for id: String) {
        var blob = blobs[id] ?? ToolBlob()
        blob.options = json
        blobs[id] = blob
        persistBlobs()
    }

    private func persistBlobs() {
        if let data = try? JSONEncoder().encode(blobs) {
            defaults.set(data, forKey: stateKey)
        }
    }
}

enum Fuzzy {
    static func score(query: String, name: String, summary: String) -> Int? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return 1 }
        let nameScore = score(query: trimmed, in: name)
        let summaryScore = score(query: trimmed, in: summary).map { $0 / 2 }
        switch (nameScore, summaryScore) {
        case let (lhs?, rhs?): return max(lhs, rhs)
        case let (lhs?, nil): return lhs
        case let (nil, rhs?): return rhs
        case (nil, nil): return nil
        }
    }

    private static func score(query: String, in text: String) -> Int? {
        let q = Array(query.lowercased())
        let t = Array(text.lowercased())
        if q.isEmpty { return 0 }
        var qi = 0
        var total = 0
        var streak = 0
        for (index, character) in t.enumerated() {
            if qi < q.count, character == q[qi] {
                streak += 1
                total += 3 + streak * 2
                if index == 0 || (index > 0 && !t[index - 1].isLetter && !t[index - 1].isNumber) {
                    total += 4
                }
                qi += 1
                if qi == q.count { return total }
            } else {
                streak = 0
            }
        }
        return nil
    }
}

struct OutputCopy: ViewModifier {
    @EnvironmentObject private var model: AppModel
    var text: () -> String

    func body(content: Content) -> some View {
        content.onChange(of: model.copyRequest) { _, value in
            guard value > 0 else { return }
            let valueText = text()
            guard !valueText.isEmpty else {
                model.flash("Nothing to copy")
                return
            }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(valueText, forType: .string)
            model.flash("Copied")
        }
    }
}

struct SampleAction: ViewModifier {
    @EnvironmentObject private var model: AppModel
    var action: () -> Void

    func body(content: Content) -> some View {
        content.onChange(of: model.sampleRequest) { _, value in
            guard value > 0 else { return }
            action()
        }
    }
}

extension View {
    func copyOutput(_ text: @escaping () -> String) -> some View {
        modifier(OutputCopy(text: text))
    }

    func onSample(_ action: @escaping () -> Void) -> some View {
        modifier(SampleAction(action: action))
    }
}
