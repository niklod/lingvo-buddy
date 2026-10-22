import Foundation
import GRDB

extension DictionaryStore {
    /// Schema statements in which this file and `DictionarySchema` differ;
    /// empty when they match. The file comes from tools/dictionary, so this is
    /// the check that keeps the two writers of the contract in step.
    public func schemaDrift() throws -> [String] {
        let contract = try DatabaseQueue()
        try contract.write { db in try DictionarySchema.create(in: db) }
        let expected = try contract.read(Self.schemaStatements)
        let actual = try reader.read(Self.schemaStatements)
        return expected.symmetricDifference(actual).sorted()
    }

    /// Whitespace is collapsed: the two writers indent their SQL differently.
    private static func schemaStatements(in db: Database) throws -> Set<String> {
        let statements = try String.fetchAll(db, sql: "SELECT sql FROM sqlite_master WHERE sql IS NOT NULL")
        return Set(statements.map { $0.split(whereSeparator: \.isWhitespace).joined(separator: " ") })
    }
}
