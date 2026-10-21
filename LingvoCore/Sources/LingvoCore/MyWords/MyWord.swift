import Foundation
import GRDB

/// A word the learner added with quick add. Progress lives in `word_progress`
/// like any other word; this row holds what the learner chose for the card.
struct MyWord: Sendable, Equatable, Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "my_words"

    /// Distractors come from words near a card's rank; a word the dictionary
    /// lacks has no rank, so it takes its options from around the end of the Top‑1000.
    static let unrankedDistractorRank = TopTier.top1000.maxRank

    let headword: String
    let translation: String
    let example: String?
    let addedAt: Date

    enum CodingKeys: String, CodingKey {
        case headword, translation, example
        case addedAt = "added_at"
    }

    /// The card data: the learner's translation first, then the dictionary's
    /// other translations so none of them can show up as a wrong option.
    func cardEntry(from dictionaryEntry: DictionaryEntry?) -> DictionaryEntry {
        guard let dictionaryEntry else {
            return DictionaryEntry(
                headword: headword,
                rank: Self.unrankedDistractorRank,
                partOfSpeech: .other,
                ipa: nil,
                example: example,
                synonymGroup: nil,
                tier: .lookup,
                translations: [.russian: [translation]]
            )
        }
        let others = (dictionaryEntry.translations[.russian] ?? []).filter { $0 != translation }
        return DictionaryEntry(
            headword: dictionaryEntry.headword,
            rank: dictionaryEntry.rank,
            partOfSpeech: dictionaryEntry.partOfSpeech,
            ipa: dictionaryEntry.ipa,
            example: example ?? dictionaryEntry.example,
            synonymGroup: dictionaryEntry.synonymGroup,
            tier: dictionaryEntry.tier,
            translations: [.russian: [translation] + others]
        )
    }
}

extension UserDatabase {
    /// Oldest first: the picker offers my words in the order they were added.
    func myWords() throws -> [MyWord] {
        try writer.read { db in
            try MyWord.order(Column("added_at"), Column("headword")).fetchAll(db)
        }
    }

    func myWord(headword: String) throws -> MyWord? {
        try writer.read { db in try MyWord.fetchOne(db, key: headword) }
    }

    /// For words the dictionary lacks, "Kubernetes" and "kubernetes" are one word.
    func myWord(ignoringCase text: String) throws -> MyWord? {
        try writer.read { db in
            try MyWord.fetchOne(db, sql: "SELECT * FROM my_words WHERE headword = ? COLLATE NOCASE", arguments: [text])
        }
    }

    func myWordsCount() throws -> Int {
        try writer.read { db in try MyWord.fetchCount(db) }
    }

    func insert(_ word: MyWord) throws {
        try writer.write { db in try word.insert(db) }
    }
}
