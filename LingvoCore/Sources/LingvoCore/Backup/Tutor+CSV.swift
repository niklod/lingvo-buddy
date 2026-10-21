import Foundation

/// What an import changed, for the message the learner sees.
public struct CSVImportSummary: Sendable, Equatable {
    /// Lines imported: one per word.
    public let words: Int
    /// Of those, words in My words.
    public let myWords: Int

    public init(words: Int, myWords: Int) {
        self.words = words
        self.myWords = myWords
    }
}

extension Tutor {
    /// My words (translation, example) and the progress of every word, as
    /// UTF-8 CSV. The answers log is not in it: streak and accuracy start over.
    public func exportCSV() throws -> Data {
        WordBackupCSV.encode(try userDatabase.backupRows())
    }

    /// All or nothing: an invalid file throws `CSVImportError` and changes
    /// nothing. Each word in the file replaces what is stored for that word;
    /// words not in the file stay as they are.
    @discardableResult
    public func importCSV(_ data: Data) throws -> CSVImportSummary {
        let rows = try WordBackupCSV.decode(data, now: clock.now())
        try userDatabase.restore(rows)
        return CSVImportSummary(words: rows.count, myWords: rows.filter { $0.myWord != nil }.count)
    }
}
