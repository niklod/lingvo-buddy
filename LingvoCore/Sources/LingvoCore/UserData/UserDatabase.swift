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
            try db.execute(sql: "DELETE FROM answers; DELETE FROM word_progress; DELETE FROM my_words;")
        }
    }

    private static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1-progress-and-answers") { db in
            try db.execute(sql: """
                CREATE TABLE word_progress (
                    headword TEXT PRIMARY KEY,
                    status TEXT NOT NULL,
                    mastery INTEGER NOT NULL DEFAULT 0,
                    last_result TEXT,
                    last_answered_at DATETIME
                );
                CREATE TABLE answers (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    headword TEXT NOT NULL,
                    direction TEXT NOT NULL,
                    result TEXT NOT NULL,
                    answered_at DATETIME NOT NULL
                );
                CREATE INDEX answers_answered_at ON answers(answered_at);
                """)
        }
        migrator.registerMigration("v2-learning-rules") { db in
            try db.execute(sql: """
                ALTER TABLE word_progress ADD COLUMN en_ru_correct BOOLEAN NOT NULL DEFAULT 0;
                ALTER TABLE word_progress ADD COLUMN ru_en_correct BOOLEAN NOT NULL DEFAULT 0;
                ALTER TABLE word_progress ADD COLUMN last_counted_correct_at DATETIME;
                ALTER TABLE word_progress ADD COLUMN review_stage INTEGER NOT NULL DEFAULT 0;
                ALTER TABLE word_progress ADD COLUMN due_at DATETIME;
                ALTER TABLE answers ADD COLUMN kind TEXT;
                """)
        }
        migrator.registerMigration("v3-settings") { db in
            try db.execute(sql: """
                CREATE TABLE settings (
                    key TEXT PRIMARY KEY,
                    value TEXT NOT NULL
                );
                """)
        }
        migrator.registerMigration("v4-my-words") { db in
            try db.execute(sql: """
                CREATE TABLE my_words (
                    headword TEXT PRIMARY KEY,
                    translation TEXT NOT NULL,
                    example TEXT,
                    added_at DATETIME NOT NULL
                );
                """)
        }
        return migrator
    }
}
