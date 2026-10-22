import Foundation
import SQLite3
import Testing

/// Writes a user database as an older app version left it, with plain SQLite:
/// the test target cannot reach GRDB, and a file built from SQL text here is
/// easier to review than a binary fixture.
enum OldUserDatabase {
    struct SQLiteError: Error, CustomStringConvertible {
        let description: String
    }

    /// `migrations` are the GRDB migration names this file already ran.
    static func create(migrations: [String], sql: String) throws -> URL {
        let url = Fixture.temporaryDatabaseURL()
        let applied = migrations.map { "INSERT INTO grdb_migrations VALUES ('\($0)');" }.joined()
        try run("CREATE TABLE grdb_migrations (identifier TEXT NOT NULL PRIMARY KEY);" + applied + sql, at: url)
        return url
    }

    /// Also writes old dictionary files: the same plain SQLite, no GRDB.
    static func run(_ sql: String, at url: URL) throws {
        var db: OpaquePointer?
        defer { sqlite3_close(db) }
        guard sqlite3_open(url.path, &db) == SQLITE_OK else {
            throw SQLiteError(description: "cannot open \(url.path)")
        }
        var message: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(db, sql, nil, nil, &message) == SQLITE_OK else {
            defer { sqlite3_free(message) }
            throw SQLiteError(description: message.map { String(cString: $0) } ?? "sqlite3_exec failed")
        }
    }
}
