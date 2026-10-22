import Foundation

/// The Dictionary window row menu. None of these is an answer: the answers
/// log, and so streak and accuracy, stay as they are.
extension Tutor {
    /// Skips a word the learner already knows: it is learned now and comes
    /// back for its first review in 7 days.
    public func markLearned(_ headword: String) throws {
        try requireKnown(headword)
        let current = try userDatabase.progress(for: headword) ?? .fresh(headword)
        guard current.status != .learned else { return }
        try userDatabase.save(current.markedLearned(at: clock.now()))
        forgetDeferral(of: headword)
    }

    /// Forgets the progress: a dictionary word goes back to the queue, a my
    /// word starts again as not answered.
    public func resetProgress(_ headword: String) throws {
        try requireKnown(headword)
        try userDatabase.deleteProgress(headword)
        forgetDeferral(of: headword)
    }

    /// Removes a my word with its progress. A queued dictionary word that was
    /// moved to My words goes back to the queue.
    public func deleteWord(_ headword: String) throws {
        guard try userDatabase.myWord(headword: headword) != nil else {
            throw LingvoCoreError.notMyWord(headword)
        }
        try userDatabase.deleteMyWord(headword)
        forgetDeferral(of: headword)
    }

    /// Cards then ask for the new translation. Setting a dictionary word back
    /// to its dictionary translation drops the learner's own one.
    public func editTranslation(_ headword: String, to translation: String) throws {
        let translation = translation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !translation.isEmpty else { throw LingvoCoreError.missingTranslation(headword) }
        guard translation.count <= NewMyWord.maxTranslationLength else {
            throw LingvoCoreError.tooLong(.translation, limit: NewMyWord.maxTranslationLength)
        }
        defer { forgetDeferral(of: headword) }
        if try userDatabase.myWord(headword: headword) != nil {
            try userDatabase.updateMyWordTranslation(headword, to: translation)
            return
        }
        guard let entry = try dictionary.entry(headword: headword) else {
            throw LingvoCoreError.unknownWord(headword)
        }
        try userDatabase.setTranslationOverride(
            headword,
            to: translation == entry.primaryRussian ? nil : translation
        )
    }

    private func requireKnown(_ headword: String) throws {
        guard try dictionary.entry(headword: headword) != nil || userDatabase.myWord(headword: headword) != nil else {
            throw LingvoCoreError.unknownWord(headword)
        }
    }
}

extension WordProgress {
    /// Like the learned transition after an answer, minus the answer: the last
    /// answer the table shows stays the real one.
    func markedLearned(at time: Date) -> WordProgress {
        let stage = ReviewSchedule.firstStage
        return WordProgress(
            headword: headword, status: .learned, mastery: Self.masteryGoal,
            lastResult: lastResult, lastAnsweredAt: lastAnsweredAt,
            enToRuCorrect: true, ruToEnCorrect: true,
            lastCountedCorrectAt: lastCountedCorrectAt, reviewStage: stage,
            dueAt: time.addingTimeInterval(ReviewSchedule.interval(forStage: stage))
        )
    }
}
