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

    /// Hands answer times to `visit`, newest first and one per local day, until
    /// it returns `false`. After each answer the walk seeks straight to the day
    /// before, so a year-long streak costs one index seek per day, not per answer.
    func walkAnswerDays(before end: Date, calendar: Calendar, visit: (Date) -> Bool) throws {
        try writer.read { db in
            var bound = end
            while let time = try Date.fetchOne(
                db, sql: "SELECT MAX(answered_at) FROM answers WHERE answered_at < ?", arguments: [bound]
            ), visit(time) {
                bound = calendar.startOfDay(for: time)
            }
        }
    }
}
