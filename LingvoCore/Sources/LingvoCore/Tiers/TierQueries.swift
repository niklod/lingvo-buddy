import Foundation
import GRDB

extension UserDatabase {
    func hasAnswer(kind: CardKind, forAnyOf headwords: Set<String>) throws -> Bool {
        guard !headwords.isEmpty else { return false }
        let placeholders = Array(repeating: "?", count: headwords.count).joined(separator: ", ")
        var arguments: StatementArguments = [kind.rawValue]
        arguments += StatementArguments(Array(headwords))
        return try writer.read { db in
            try Bool.fetchOne(
                db,
                sql: "SELECT EXISTS (SELECT 1 FROM answers WHERE kind = ? AND headword IN (\(placeholders)))",
                arguments: arguments
            ) ?? false
        }
    }
}
