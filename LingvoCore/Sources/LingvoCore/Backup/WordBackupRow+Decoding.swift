import Foundation

extension WordBackupRow {
    /// `now` stands in for an empty `added_at`, so a hand-made list of
    /// "headword,translation" lines imports as new my words.
    /// `headword` is the stored spelling of the line's headword (see `ImportHeadwords`).
    init(reading reader: CSVFieldReader, headword: String, now: Date) throws(CSVImportError) {
        self.init(
            headword: headword,
            myWord: try Self.myWord(headword, reader: reader, now: now),
            progress: try Self.progress(headword, reader: reader),
            ownTranslation: try reader.text(.ownTranslation, limit: NewMyWord.maxTranslationLength)
        )
        guard myWord != nil || progress != nil || ownTranslation != nil else {
            throw .nothingToImport(line: reader.line, headword: headword)
        }
    }

    private static func myWord(_ headword: String, reader: CSVFieldReader, now: Date) throws(CSVImportError) -> MyWord? {
        let example = try reader.text(.example, limit: NewMyWord.maxExampleLength)
        let addedAt = try reader.date(.addedAt)
        guard let translation = try reader.text(.translation, limit: NewMyWord.maxTranslationLength) else {
            if example != nil || addedAt != nil {
                throw .missingValue(line: reader.line, column: WordBackupColumn.translation.rawValue)
            }
            return nil
        }
        return MyWord(
            headword: headword,
            translation: translation,
            example: example,
            addedAt: addedAt ?? now,
            ipa: try reader.text(.ipa, limit: NewMyWord.maxIPALength),
            partOfSpeech: try reader.choice(.partOfSpeech, of: PartOfSpeech.self)
        )
    }

    private static func progress(_ headword: String, reader: CSVFieldReader) throws(CSVImportError) -> WordProgress? {
        guard let status = try reader.choice(.status, of: WordStatus.self) else {
            if let filled = WordBackupColumn.progressColumns.first(where: { reader.text($0) != nil }) {
                throw .progressWithoutStatus(line: reader.line, column: filled.rawValue)
            }
            return nil
        }
        return WordProgress(
            headword: headword,
            status: status,
            mastery: try reader.int(.mastery, in: 0...WordProgress.masteryGoal) ?? 0,
            lastResult: try reader.choice(.lastResult, of: AnswerOutcome.self),
            lastAnsweredAt: try reader.date(.lastAnsweredAt),
            enToRuCorrect: try reader.bool(.enToRuCorrect) ?? false,
            ruToEnCorrect: try reader.bool(.ruToEnCorrect) ?? false,
            lastCountedCorrectAt: try reader.date(.lastCountedCorrectAt),
            reviewStage: try reader.int(.reviewStage, in: 0...ReviewSchedule.lastStage) ?? 0,
            dueAt: try reader.date(.dueAt)
        )
    }
}
