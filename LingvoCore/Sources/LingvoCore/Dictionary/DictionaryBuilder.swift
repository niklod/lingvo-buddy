import Foundation
import GRDB

/// Writes dictionary sources into the bundled SQLite contract (see `DictionarySchema`).
public enum DictionaryBuilder {
    /// Builds a dictionary file at `url`, replacing any file that is already there.
    public static func buildFile(from source: DictionarySource, at url: URL) throws {
        try removeFileIfPresent(at: url)
        let queue = try DatabaseQueue(path: url.path)
        try write(source, into: queue)
        // The bundle is read-only: rollback-journal mode keeps SQLite from needing
        // -wal/-shm files next to the bundled file.
        try queue.writeWithoutTransaction { db in
            try db.execute(sql: "PRAGMA journal_mode = DELETE")
            try db.execute(sql: "VACUUM")
        }
        try queue.close()
    }

    static func write(_ source: DictionarySource, into writer: some DatabaseWriter) throws {
        do {
            try writer.write { db in
                try DictionarySchema.create(in: db)
                for (index, entry) in source.entries.enumerated() {
                    try insert(entry, id: index + 1, in: db)
                }
                for headword in source.quizExclusions {
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

    private static func insert(_ entry: DictionaryEntry, id: Int, in db: Database) throws {
        try db.execute(
            sql: """
                INSERT INTO entries (id, headword, rank, pos, ipa, example, synonym_group, tier)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
            arguments: [
                id, entry.headword, entry.rank, entry.partOfSpeech.rawValue,
                entry.ipa, entry.example, entry.synonymGroup, entry.tier.rawValue,
            ]
        )
        for (language, texts) in entry.translations.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            for (order, text) in texts.enumerated() {
                try db.execute(
                    sql: "INSERT INTO translations (entry_id, lang, ord, text) VALUES (?, ?, ?, ?)",
                    arguments: [id, language.rawValue, order, text]
                )
            }
        }
    }

    private static func removeFileIfPresent(at url: URL) throws {
        let manager = FileManager.default
        for suffix in ["", "-journal", "-wal", "-shm"] {
            let path = url.path + suffix
            if manager.fileExists(atPath: path) {
                try manager.removeItem(atPath: path)
            }
        }
    }
}
