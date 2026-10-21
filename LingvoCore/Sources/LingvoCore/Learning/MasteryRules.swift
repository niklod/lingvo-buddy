import Foundation

/// How one answer changes a word's progress (spec "Learning rules").
extension WordProgress {
    /// Quick repeats are guesses, not learning: a correct answer adds a dot only
    /// this long after the previous counted one.
    static let countedCorrectGap: TimeInterval = 60 * 60

    func applying(_ outcome: AnswerOutcome, direction: Direction, at time: Date) -> WordProgress {
        guard outcome == .correct else { return reset(after: outcome, at: time) }
        return status == .learned
            ? passingReview(at: time)
            : correctWhileLearning(direction: direction, at: time)
    }

    /// Wrong and "Don't know" alike: back to learning with no dots, due again now.
    private func reset(after outcome: AnswerOutcome, at time: Date) -> WordProgress {
        WordProgress(
            headword: headword,
            status: .learning,
            mastery: 0,
            lastResult: outcome,
            lastAnsweredAt: time,
            dueAt: time
        )
    }

    private func passingReview(at time: Date) -> WordProgress {
        let stage = ReviewSchedule.nextStage(after: reviewStage)
        return learned(stage: stage, mastery: mastery, at: time)
    }

    private func correctWhileLearning(direction: Direction, at time: Date) -> WordProgress {
        let enToRu = enToRuCorrect || direction == .enToRu
        let ruToEn = ruToEnCorrect || direction == .ruToEn
        let completesMastery = mastery + 1 >= Self.masteryGoal
        // At the last dot both directions must be covered; otherwise the
        // next card is forced to the missing one and this answer does not count.
        let counts = isPastGap(at: time) && (!completesMastery || (enToRu && ruToEn))
        guard counts else {
            return WordProgress(
                headword: headword, status: .learning, mastery: mastery,
                lastResult: .correct, lastAnsweredAt: time,
                enToRuCorrect: enToRu, ruToEnCorrect: ruToEn,
                lastCountedCorrectAt: lastCountedCorrectAt, dueAt: dueAt
            )
        }
        if completesMastery {
            return learned(stage: ReviewSchedule.firstStage, mastery: Self.masteryGoal, at: time)
        }
        return WordProgress(
            headword: headword, status: .learning, mastery: mastery + 1,
            lastResult: .correct, lastAnsweredAt: time,
            enToRuCorrect: enToRu, ruToEnCorrect: ruToEn,
            lastCountedCorrectAt: time, dueAt: time.addingTimeInterval(Self.countedCorrectGap)
        )
    }

    private func learned(stage: Int, mastery: Int, at time: Date) -> WordProgress {
        WordProgress(
            headword: headword, status: .learned, mastery: mastery,
            lastResult: .correct, lastAnsweredAt: time,
            enToRuCorrect: true, ruToEnCorrect: true,
            lastCountedCorrectAt: time, reviewStage: stage,
            dueAt: time.addingTimeInterval(ReviewSchedule.interval(forStage: stage))
        )
    }

    private func isPastGap(at time: Date) -> Bool {
        guard let lastCountedCorrectAt else { return true }
        return time.timeIntervalSince(lastCountedCorrectAt) >= Self.countedCorrectGap
    }
}

/// Learned words come back after 7, then 21, then every 60 days.
enum ReviewSchedule {
    private static let intervalsInDays: [Double] = [7, 21, 60]
    private static let day: TimeInterval = 24 * 60 * 60

    static let firstStage = 1

    static func nextStage(after stage: Int) -> Int {
        min(max(stage, 0) + 1, intervalsInDays.count)
    }

    static func interval(forStage stage: Int) -> TimeInterval {
        let index = min(max(stage, firstStage), intervalsInDays.count) - 1
        return intervalsInDays[index] * day
    }
}
