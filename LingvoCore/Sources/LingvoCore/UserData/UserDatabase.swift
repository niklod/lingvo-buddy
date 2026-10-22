import Foundation
import GRDB

/// The writable database with the learner's state (progress, answers log, settings).
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

    /// Removes all learner state. Used by QA hooks that seed a known state.
    public func eraseAll() throws {
        try writer.write { db in
            try db.execute(sql: "DELETE FROM answers; DELETE FROM word_progress; DELETE FROM my_words; DELETE FROM translation_overrides;")
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
