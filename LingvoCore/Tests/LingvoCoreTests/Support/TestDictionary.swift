import Foundation
import LingvoCore

/// Small hand-made dictionaries for rules that need a specific word first or
/// a specific set of neighbours.
enum TestDictionary {
    struct Entry {
        let headword: String
        let rank: Int
        let pos: String
        let ru: [String]
        let synonymGroup: String?

        init(_ headword: String, rank: Int, pos: String, ru: [String], synonymGroup: String? = nil) {
            self.headword = headword
            self.rank = rank
            self.pos = pos
            self.ru = ru
            self.synonymGroup = synonymGroup
        }
    }

    static func make(_ entries: [Entry]) throws -> DictionaryStore {
        let json: [String: Any] = [
            "entries": entries.map { entry in
                [
                    "headword": entry.headword,
                    "rank": entry.rank,
                    "pos": entry.pos,
                    "ipa": "/\(entry.headword)/",
                    "example": "An example with \(entry.headword).",
                    "synonym_group": entry.synonymGroup ?? entry.headword,
                    "tier": "quiz",
                    "translations": ["ru": entry.ru],
                ] as [String: Any]
            },
        ]
        return try DictionaryStore.inMemory(fromJSON: [JSONSerialization.data(withJSONObject: json)])
    }
}
