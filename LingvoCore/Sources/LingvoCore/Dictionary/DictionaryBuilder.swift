import Foundation
import GRDB

/// Writes JSON dictionary sources into the bundled SQLite contract for tests
/// and previews. The shipped file comes from tools/dictionary; this writer
/// follows it row for row, so tests run on the data rules the app gets.
enum DictionaryBuilder {
    static func write(_ source: DictionarySource, into writer: some DatabaseWriter) throws {
        do {
            try writer.write { db in
                try DictionarySchema.create(in: db)
                for entry in source.entries {
                    try insert(entry, in: db)
                }
                // Like the Python build: an exclusion of a word the source lacks
                // (a partial build) is skipped, not an error.
                let built = Set(source.entries.map(\.headword))
                for headword in Set(source.quizExclusions).intersection(built).sorted() {
                    try db.execute(sql: "INSERT INTO quiz_exclusions (headword) VALUES (?)", arguments: [headword])
                }
                for (key, value) in source.meta.sorted(by: { $0.key < $1.key }) {
                    try db.execute(sql: "INSERT INTO meta (key, value) VALUES (?, ?)", arguments: [key, value])
                }
            }
        } catch let error as DatabaseError {
            throw LingvoCoreError.invalidDictionary(error.message ?? error.description)
        }
    }

    /// The id equals the rank, as in the Python build, so ids stay stable across rebuilds.
    private static func insert(_ entry: DictionaryEntry, in db: Database) throws {
        try db.execute(
            sql: """
                INSERT INTO entries (id, headword, rank, pos, ipa, example, synonym_group, tier)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
            arguments: [
                entry.rank, entry.headword, entry.rank, entry.partOfSpeech.rawValue,
                entry.ipa, entry.example, entry.synonymGroup, entry.tier.rawValue,
            ]
        )
        for (language, texts) in entry.translations.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            for (order, text) in texts.enumerated() {
                try db.execute(
                    sql: "INSERT INTO translations (entry_id, lang, ord, text) VALUES (?, ?, ?, ?)",
                    arguments: [entry.rank, language.rawValue, order, text]
                )
            }
        }
    }
}
