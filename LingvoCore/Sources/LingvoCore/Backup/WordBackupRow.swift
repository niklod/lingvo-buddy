import Foundation

/// One CSV line: everything the learner has for one word. A word is in My
/// words when it has a translation, and has progress when it has a status.
struct WordBackupRow: Sendable, Equatable {
    let headword: String
    let myWord: MyWord?
    let progress: WordProgress?
    /// A translation the learner set for a dictionary word in the Dictionary window.
    var ownTranslation: String?
}

/// The CSV columns, in export order.
enum WordBackupColumn: String, CaseIterable, Sendable {
    case headword
    case translation
    case example
    case addedAt = "added_at"
    case status
    case mastery
    case enToRuCorrect = "en_ru_correct"
    case ruToEnCorrect = "ru_en_correct"
    case reviewStage = "review_stage"
    case dueAt = "due_at"
    case lastResult = "last_result"
    case lastAnsweredAt = "last_answered_at"
    case lastCountedCorrectAt = "last_counted_correct_at"
    /// Last, so files from before the Dictionary window keep their column order.
    case ownTranslation = "own_translation"

    static let myWordColumns: [WordBackupColumn] = [.translation, .example, .addedAt]
    static let progressColumns: [WordBackupColumn] = [
        .mastery, .enToRuCorrect, .ruToEnCorrect, .reviewStage,
        .dueAt, .lastResult, .lastAnsweredAt, .lastCountedCorrectAt,
    ]
}

extension WordBackupRow {
    /// The fields in `WordBackupColumn` order.
    var fields: [String] {
        WordBackupColumn.allCases.map(field)
    }

    private func field(_ column: WordBackupColumn) -> String {
        switch column {
        case .headword: headword
        case .translation: myWord?.translation ?? ""
        case .example: myWord?.example ?? ""
        case .addedAt: Self.text(myWord?.addedAt)
        case .status: progress?.status.rawValue ?? ""
        case .mastery: progress.map { String($0.mastery) } ?? ""
        case .enToRuCorrect: progress.map { Self.text($0.enToRuCorrect) } ?? ""
        case .ruToEnCorrect: progress.map { Self.text($0.ruToEnCorrect) } ?? ""
        case .reviewStage: progress.map { String($0.reviewStage) } ?? ""
        case .dueAt: Self.text(progress?.dueAt)
        case .lastResult: progress?.lastResult?.rawValue ?? ""
        case .lastAnsweredAt: Self.text(progress?.lastAnsweredAt)
        case .lastCountedCorrectAt: Self.text(progress?.lastCountedCorrectAt)
        case .ownTranslation: ownTranslation ?? ""
        }
    }

    private static func text(_ date: Date?) -> String {
        date.map { CSVTimestamp($0).iso } ?? ""
    }

    private static func text(_ flag: Bool) -> String {
        flag ? "1" : "0"
    }
}
