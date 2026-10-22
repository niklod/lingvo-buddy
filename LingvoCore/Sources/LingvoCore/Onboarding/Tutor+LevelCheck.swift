import Foundation

extension Tutor {
    /// About 30 words spread over the open tier, easiest first. Words the
    /// learner already has progress on are left out: their state is known.
    public func levelCheckSample(size: Int = LevelCheckSample.defaultSize) throws -> LevelCheckSample {
        let progress = try userDatabase.allProgress()
        let tier = try openTier(progress: progress)
        let queued = dictionary.quizEntries.filter { $0.rank <= tier.maxRank && progress[$0.headword] == nil }
        return LevelCheckSample(
            tier: tier,
            words: LevelCheckSampler.sample(from: queued, size: size, random: random)
        )
    }

    /// Marks the known sample words learned, and every queued word of the tier
    /// below the learner's level too, except words the learner did not know.
    /// Their first reviews are spread over days 7 to 60, hardest words first.
    /// Logs no answers: the level check is not practice. Words with progress
    /// keep it. An answer for a word that is not a card word throws
    /// `unknownWord`, and nothing is saved.
    @discardableResult
    public func applyLevelCheck(_ answers: [LevelCheckAnswer]) throws -> LevelCheckOutcome {
        let cardWords = Dictionary(dictionary.quizEntries.map { ($0.headword, $0.rank) }, uniquingKeysWith: min)
        let ranked = try answers.map { answer in
            guard let rank = cardWords[answer.headword] else { throw LingvoCoreError.unknownWord(answer.headword) }
            return (rank: rank, knows: answer.knows)
        }
        let levelRank = LevelCheckPlacement.levelRank(ranked.sorted { $0.rank < $1.rank }) ?? 0
        let known = Set(answers.filter(\.knows).map(\.headword))
        let unknown = Set(answers.filter { !$0.knows }.map(\.headword))
        let progress = try userDatabase.allProgress()
        let now = clock.now()
        let entries = dictionary.quizEntries.filter { entry in
            progress[entry.headword] == nil && !unknown.contains(entry.headword)
                && (known.contains(entry.headword) || entry.rank <= levelRank)
        }
        let learned = LevelCheckReviewSpread.reviewOrder(entries).enumerated().map { index, entry in
            WordProgress.knownBeforePractice(
                entry.headword,
                at: now,
                firstReviewDelay: LevelCheckReviewSpread.firstReviewDelay(index: index, of: entries.count)
            )
        }
        try userDatabase.save(learned)
        return LevelCheckOutcome(learnedCount: learned.count, levelRank: levelRank > 0 ? levelRank : nil)
    }
}
