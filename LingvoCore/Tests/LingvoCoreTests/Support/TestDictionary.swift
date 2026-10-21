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
        let tier: DictionaryTier

        init(_ headword: String, rank: Int, pos: String, ru: [String], synonymGroup: String? = nil) {
            self.headword = headword
            self.rank = rank
            self.pos = pos
            self.ru = ru
            self.synonymGroup = synonymGroup
            self.tier = .quiz
        }

        /// A lookup-tier word, as the real dictionary has above rank 1000: no example, no synonym group.
        static func lookup(_ headword: String, rank: Int, pos: String, ru: [String]) -> Entry {
            Entry(headword, rank: rank, pos: pos, ru: ru, tier: .lookup)
        }

        private init(_ headword: String, rank: Int, pos: String, ru: [String], tier: DictionaryTier) {
            self.headword = headword
            self.rank = rank
            self.pos = pos
            self.ru = ru
            self.synonymGroup = nil
            self.tier = tier
        }

        var json: [String: Any] {
            let isQuiz = tier == .quiz
            return [
                "headword": headword,
                "rank": rank,
                "pos": pos,
                "ipa": "/\(headword)/",
                "example": isQuiz ? "An example with \(headword)." : NSNull(),
                "synonym_group": isQuiz ? (synonymGroup ?? headword) : NSNull(),
                "tier": tier.rawValue,
                "translations": ["ru": ru],
            ]
        }
    }

    static func make(_ entries: [Entry], quizExclusions: [String] = []) throws -> DictionaryStore {
        let json: [String: Any] = [
            "entries": entries.map(\.json),
            "quiz_exclusions": quizExclusions,
        ]
        return try DictionaryStore.inMemory(fromJSON: [JSONSerialization.data(withJSONObject: json)])
    }
}
