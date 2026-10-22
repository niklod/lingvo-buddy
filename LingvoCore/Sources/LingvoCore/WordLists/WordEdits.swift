import Foundation
import GRDB

extension UserDatabase {
    /// The learner's own translations of dictionary words (my words keep theirs in `my_words`).
    func translationOverrides() throws -> [String: String] {
        try writer.read { db in
            try Row.fetchAll(db, sql: "SELECT headword, translation FROM translation_overrides")
                .reduce(into: [:]) { result, row in result[row["headword"]] = row["translation"] }
        }
    }

    func translationOverride(for headword: String) throws -> String? {
        try writer.read { db in
            try String.fetchOne(
                db, sql: "SELECT translation FROM translation_overrides WHERE headword = ?", arguments: [headword]
            )
        }
    }

    /// `nil` removes the override.
    func setTranslationOverride(_ headword: String, to translation: String?) throws {
        try writer.write { db in
            guard let translation else {
                try db.execute(sql: "DELETE FROM translation_overrides WHERE headword = ?", arguments: [headword])
                return
            }
            try db.execute(
                sql: """
                    INSERT INTO translation_overrides (headword, translation) VALUES (?, ?)
                    ON CONFLICT(headword) DO UPDATE SET translation = excluded.translation
                    """,
                arguments: [headword, translation]
            )
        }
    }

    func updateMyWordTranslation(_ headword: String, to translation: String) throws {
        try writer.write { db in
            try db.execute(sql: "UPDATE my_words SET translation = ? WHERE headword = ?", arguments: [translation, headword])
        }
    }

    func deleteProgress(_ headword: String) throws {
        try writer.write { db in
            try db.execute(sql: "DELETE FROM word_progress WHERE headword = ?", arguments: [headword])
        }
    }

    /// The answers log stays: it is the history behind streak and accuracy.
    func deleteMyWord(_ headword: String) throws {
        try writer.write { db in try Self.deleteWordRows(headword, in: db) }
    }
}

extension DictionaryEntry {
    /// The card asks for `translation`; the other dictionary translations stay
    /// so none of them can show up as a wrong option. An own `example` drops the
    /// dictionary's Russian example: it translates a different sentence.
    func withPrimaryTranslation(_ translation: String, example: String? = nil) -> DictionaryEntry {
        let others = (translations[.russian] ?? []).filter { $0 != translation }
        return DictionaryEntry(
            headword: headword,
            rank: rank,
            partOfSpeech: partOfSpeech,
            ipa: ipa,
            example: example ?? self.example,
            synonymGroup: synonymGroup,
            tier: tier,
            translations: [.russian: [translation] + others],
            russianExample: example == nil ? russianExample : nil
        )
    }
}
