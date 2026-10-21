import Foundation
import GRDB

extension UserDatabase {
    /// Every word with progress or in My words, sorted by headword.
    func backupRows() throws -> [WordBackupRow] {
        try writer.read { db in
            let progress = try WordProgress.fetchAll(db).reduce(into: [String: WordProgress]()) { $0[$1.headword] = $1 }
            let myWords = try MyWord.fetchAll(db).reduce(into: [String: MyWord]()) { $0[$1.headword] = $1 }
            return Set(progress.keys).union(myWords.keys).sorted().map { headword in
                WordBackupRow(headword: headword, myWord: myWords[headword], progress: progress[headword])
            }
        }
    }

    /// Each row replaces everything stored for its word; words not in `rows`
    /// stay as they are. One transaction: a failure leaves no partial import.
    func restore(_ rows: [WordBackupRow]) throws {
        try writer.write { db in
            for row in rows {
                try db.execute(sql: "DELETE FROM my_words WHERE headword = ?", arguments: [row.headword])
                try db.execute(sql: "DELETE FROM word_progress WHERE headword = ?", arguments: [row.headword])
                if let myWord = row.myWord {
                    try insert(myWord, into: db)
                }
                if let progress = row.progress {
                    try insert(progress, into: db)
                }
            }
        }
    }

    // Dates go in as text built from whole milliseconds (see `CSVTimestamp`),
    // so a second export prints exactly the times of the first.
    private func insert(_ word: MyWord, into db: Database) throws {
        try db.execute(
            sql: "INSERT INTO my_words (headword, translation, example, added_at) VALUES (?, ?, ?, ?)",
            arguments: [word.headword, word.translation, word.example, Self.text(word.addedAt)]
        )
    }

    private func insert(_ progress: WordProgress, into db: Database) throws {
        try db.execute(
            sql: """
                INSERT INTO word_progress (
                    headword, status, mastery, last_result, last_answered_at, en_ru_correct,
                    ru_en_correct, last_counted_correct_at, review_stage, due_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
            arguments: [
                progress.headword, progress.status.rawValue, progress.mastery, progress.lastResult?.rawValue,
                Self.text(progress.lastAnsweredAt), progress.enToRuCorrect, progress.ruToEnCorrect,
                Self.text(progress.lastCountedCorrectAt), progress.reviewStage, Self.text(progress.dueAt),
            ]
        )
    }

    private static func text(_ date: Date?) -> String? {
        date.map { CSVTimestamp($0).databaseText }
    }
}
