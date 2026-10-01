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
    @Published private var blobs: [String: ToolBlob] = [:]

    private let defaults = UserDefaults.standard
    private let lastKey = "devkit.lastTool"
    private let favoritesKey = "devkit.favorites"
    private let recentKey = "devkit.recent"
    private let stateKey = "devkit.toolState"

    init() {
        selectedToolID = defaults.string(forKey: lastKey)
        favorites = defaults.stringArray(forKey: favoritesKey) ?? []
        recent = defaults.stringArray(forKey: recentKey) ?? []
        if let data = defaults.data(forKey: stateKey),
           let decoded = try? JSONDecoder().decode([String: ToolBlob].self, from: data) {
            blobs = decoded
        }
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
