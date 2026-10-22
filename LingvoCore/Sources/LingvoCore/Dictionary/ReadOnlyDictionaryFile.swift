import Foundation
import GRDB

/// What the bundled and the extended dictionary share: a read-only SQLite file from tools/dictionary
/// with a schema version, a meta table and a contract schema in LingvoCore.
enum ReadOnlyDictionaryFile {
    /// `name` goes into the error messages ("extended dictionary").
    static func open(at url: URL, name: String) throws -> DatabaseQueue {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw LingvoCoreError.invalidDictionary("no \(name) file at \(url.path)")
        }
        var configuration = Configuration()
        configuration.readonly = true
        return try DatabaseQueue(path: url.path, configuration: configuration)
    }

    /// A file built for an older contract lacks what this code reads; fail with
    /// a clear message instead of an SQL error on the first card.
    static func checkVersion(_ expected: Int, name: String, in db: Database) throws {
        let version = try Int.fetchOne(db, sql: "PRAGMA user_version") ?? 0
        guard version == expected else {
            throw LingvoCoreError.invalidDictionary("\(name) schema version \(version), expected \(expected): rebuild it")
        }
    }

    static func meta(in reader: any DatabaseReader) throws -> [String: String] {
        try reader.read { db in
            try Row.fetchAll(db, sql: "SELECT key, value FROM meta").reduce(into: [:]) { result, row in
                result[row["key"]] = row["value"]
            }
        }
    }

    /// Schema statements in which the file and the contract differ; empty when they match.
    static func schemaDrift(of reader: any DatabaseReader, contract: (Database) throws -> Void) throws -> [String] {
        let expectedQueue = try DatabaseQueue()
        try expectedQueue.write(contract)
        let expected = try expectedQueue.read(schemaStatements)
        let actual = try reader.read(schemaStatements)
        return expected.symmetricDifference(actual).sorted()
    }

    /// The values of a CHECK (... IN (...)) constraint.
    static func quotedList(_ values: [String]) -> String {
        values.map { "'\($0)'" }.joined(separator: ", ")
    }

    /// Whitespace is collapsed: the two writers indent their SQL differently.
    private static func schemaStatements(in db: Database) throws -> Set<String> {
        let statements = try String.fetchAll(db, sql: "SELECT sql FROM sqlite_master WHERE sql IS NOT NULL")
        return Set(statements.map { $0.split(whereSeparator: \.isWhitespace).joined(separator: " ") })
    }
}
