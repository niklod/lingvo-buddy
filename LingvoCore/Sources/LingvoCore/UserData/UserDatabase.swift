import Foundation
import GRDB

/// The writable database with the learner's state: progress, answers log,
/// settings, my words and own translations.
///
/// Rows key words by `headword`, not by dictionary id: dictionary ids change
/// whenever the bundled dictionary is rebuilt, headwords do not.
public struct UserDatabase: Sendable {
    let writer: any DatabaseWriter

    private init(writer: any DatabaseWriter) throws {
        self.writer = writer
        try Self.migrator.migrate(writer)
    }

    /// Opens (or creates) the database file at `url`, creating parent folders.
    public static func open(at url: URL) throws -> UserDatabase {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        return try UserDatabase(writer: DatabaseQueue(path: url.path))
    }

    public static func inMemory() throws -> UserDatabase {
        try UserDatabase(writer: DatabaseQueue())
    }

    /// Every table keyed by headword, in one place so that a new per-word table
    /// is not missed by delete, import or erase. The answers log is not one: it is history.
    static let wordTables = ["my_words", "word_progress", "translation_overrides"]

    /// Removes all learner state. Used by QA hooks that seed a known state.
    public func eraseAll() throws {
        try writer.write { db in
            for table in ["answers"] + Self.wordTables {
                try db.execute(sql: "DELETE FROM \(table)")
            }
        }
    }

    static func deleteWordRows(_ headword: String, in db: Database) throws {
        for table in wordTables {
            try db.execute(sql: "DELETE FROM \(table) WHERE headword = ?", arguments: [headword])
        }
    }

    private static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        for migration in UserSchema.migrations {
            migrator.registerMigration(migration.name) { db in try db.execute(sql: migration.sql) }
        }
        return migrator
    }
}
