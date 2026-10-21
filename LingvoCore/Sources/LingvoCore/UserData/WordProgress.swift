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
    /// Correct answers per direction since the last reset (the both-directions rule).
    let enToRuCorrect: Bool
    let ruToEnCorrect: Bool
    let lastCountedCorrectAt: Date?
    /// 0 while learning; 1, 2, 3 for the 7, 21 and 60 day review steps.
    let reviewStage: Int
    /// `nil` means due now (also for rows written before the due date existed).
    let dueAt: Date?

    enum CodingKeys: String, CodingKey {
        case headword, status, mastery
        case lastResult = "last_result"
        case lastAnsweredAt = "last_answered_at"
        case enToRuCorrect = "en_ru_correct"
        case ruToEnCorrect = "ru_en_correct"
        case lastCountedCorrectAt = "last_counted_correct_at"
        case reviewStage = "review_stage"
        case dueAt = "due_at"
    }

    init(
        headword: String,
        status: WordStatus,
        mastery: Int,
        lastResult: AnswerOutcome?,
        lastAnsweredAt: Date?,
        enToRuCorrect: Bool = false,
        ruToEnCorrect: Bool = false,
        lastCountedCorrectAt: Date? = nil,
        reviewStage: Int = 0,
        dueAt: Date? = nil
    ) {
        self.headword = headword
        self.status = status
        self.mastery = mastery
        self.lastResult = lastResult
        self.lastAnsweredAt = lastAnsweredAt
        self.enToRuCorrect = enToRuCorrect
        self.ruToEnCorrect = ruToEnCorrect
        self.lastCountedCorrectAt = lastCountedCorrectAt
        self.reviewStage = reviewStage
        self.dueAt = dueAt
    }

    static func fresh(_ headword: String) -> WordProgress {
        WordProgress(headword: headword, status: .learning, mastery: 0, lastResult: nil, lastAnsweredAt: nil)
    }

    func isDue(at time: Date) -> Bool {
        dueAt.map { $0 <= time } ?? true
    }

    func hasCorrect(in direction: Direction) -> Bool {
        switch direction {
        case .enToRu: enToRuCorrect
        case .ruToEn: ruToEnCorrect
        }
    }
}

struct AnswerRecord: Sendable, Codable, PersistableRecord {
    static let databaseTableName = "answers"

    let headword: String
    let direction: Direction
    let kind: CardKind
    let result: AnswerOutcome
    let answeredAt: Date

    enum CodingKeys: String, CodingKey {
        case headword, direction, kind, result
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

    /// Card kinds of the latest answers, newest first. Rows from before kinds
    /// were logged come back as `nil`.
    func recentAnswerKinds(limit: Int) throws -> [CardKind?] {
        guard limit > 0 else { return [] }
        return try writer.read { db in
            try String?.fetchAll(db, sql: "SELECT kind FROM answers ORDER BY id DESC LIMIT ?", arguments: [limit])
                .map { $0.flatMap(CardKind.init(rawValue:)) }
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
