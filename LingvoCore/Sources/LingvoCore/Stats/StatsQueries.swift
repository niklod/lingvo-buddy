import Foundation
import GRDB

/// One row of the answers log, as the stats need it.
struct LoggedAnswer: Sendable, Decodable, FetchableRecord {
    let result: AnswerOutcome
    let answeredAt: Date

    enum CodingKeys: String, CodingKey {
        case result
        case answeredAt = "answered_at"
    }
}

extension UserDatabase {
    /// Answers at or after `start`, oldest first.
    func answers(since start: Date) throws -> [LoggedAnswer] {
        try writer.read { db in
            try LoggedAnswer.fetchAll(
                db,
                sql: "SELECT result, answered_at FROM answers WHERE answered_at >= ? ORDER BY answered_at",
                arguments: [start]
            )
        }
    }

    /// Hands answer times to `visit`, newest first, until it returns `false`.
    /// A cursor, so a long streak walk does not load the whole log at once.
    func walkAnswerTimes(newestFirst visit: (Date) -> Bool) throws {
        try writer.read { db in
            let times = try Date.fetchCursor(db, sql: "SELECT answered_at FROM answers ORDER BY answered_at DESC")
            while let time = try times.next(), visit(time) {}
        }
    }
}
