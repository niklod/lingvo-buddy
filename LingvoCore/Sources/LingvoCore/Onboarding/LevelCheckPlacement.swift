import Foundation

/// Where the learner's level ends: the hardest known sample word such that
/// at least 80% of the sample words up to it are known. One miss among easy
/// words does not drag the level down; many misses keep it low.
enum LevelCheckPlacement {
    static let requiredKnownShare = 0.8

    /// `answers` must be sorted easiest first; returns the rank of the level word.
    static func levelRank(_ answers: [(rank: Int, knows: Bool)]) -> Int? {
        var known = 0
        var level: Int?
        for (index, answer) in answers.enumerated() where answer.knows {
            known += 1
            if Double(known) / Double(index + 1) >= requiredKnownShare {
                level = answer.rank
            }
        }
        return level
    }
}

extension WordProgress {
    /// A word the learner knew before any practice. It skips the 7 and 21 day
    /// steps: reviewing "the" or "have" after a week would waste cards. The
    /// first review comes after `firstReviewDelay`; the last stage then keeps
    /// every later review 60 days apart.
    static func knownBeforePractice(_ headword: String, at time: Date, firstReviewDelay: TimeInterval) -> WordProgress {
        WordProgress(
            headword: headword,
            status: .learned,
            mastery: masteryGoal,
            lastResult: nil,
            lastAnsweredAt: nil,
            enToRuCorrect: true,
            ruToEnCorrect: true,
            reviewStage: ReviewSchedule.lastStage,
            dueAt: time.addingTimeInterval(firstReviewDelay)
        )
    }
}
