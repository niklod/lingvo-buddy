import Foundation
import GRDB

public enum WordStatus: String, Sendable, Codable {
    case learning
    case learned
}

public enum AnswerOutcome: String, Sendable, Codable {
    case correct
    case wrong
    case dontKnow = "dont_know"
}

/// The learner's state for one word. A word with no progress row is still queued.
struct WordProgress: Sendable, Equatable, Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "word_progress"
    static let masteryGoal = 4

    let headword: String
    let status: WordStatus
    let mastery: Int
    let lastResult: AnswerOutcome?
    let lastAnsweredAt: Date?

    enum CodingKeys: String, CodingKey {
        case headword, status, mastery
        case lastResult = "last_result"
        case lastAnsweredAt = "last_answered_at"
    }

    static func fresh(_ headword: String) -> WordProgress {
        WordProgress(headword: headword, status: .learning, mastery: 0, lastResult: nil, lastAnsweredAt: nil)
    }

    func applying(_ outcome: AnswerOutcome, at time: Date) -> WordProgress {
        let newMastery = outcome == .correct ? min(mastery + 1, Self.masteryGoal) : 0
        return WordProgress(
            headword: headword,
            status: newMastery == Self.masteryGoal ? .learned : .learning,
            mastery: newMastery,
            lastResult: outcome,
            lastAnsweredAt: time
        )
    }
}

struct AnswerRecord: Sendable, Codable, PersistableRecord {
    static let databaseTableName = "answers"

    let headword: String
    let direction: Direction
    let result: AnswerOutcome
    let answeredAt: Date

    enum CodingKeys: String, CodingKey {
        case headword, direction, result
        case answeredAt = "answered_at"
    }
}

extension UserDatabase {
    func progress(for headword: String) throws -> WordProgress? {
        try writer.read { db in try WordProgress.fetchOne(db, key: headword) }
    }

    func allProgress() throws -> [String: WordProgress] {
        try writer.read { db in
            try WordProgress.fetchAll(db).reduce(into: [:]) { result, progress in
                result[progress.headword] = progress
            }
        }
    }

    func record(_ answer: AnswerRecord, updating progress: WordProgress) throws {
        try writer.write { db in
            try answer.insert(db)
            try progress.save(db)
        }
    }

    func save(_ progress: WordProgress) throws {
        try writer.write { db in try progress.save(db) }
    }
}
