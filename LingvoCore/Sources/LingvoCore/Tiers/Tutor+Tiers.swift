import Foundation

extension Tutor {
    /// The tier new words come from; card labels and the progress card follow it.
    public func openTier() throws -> TopTier {
        try openTier(progress: userDatabase.allProgress())
    }

    public func tierProgress() throws -> TierProgress {
        let progress = try userDatabase.allProgress()
        let tier = try openTier(progress: progress)
        let words = dictionary.quizEntries.filter { $0.rank <= tier.maxRank }
        let learned = words.filter { progress[$0.headword]?.status == .learned }.count
        return TierProgress(tier: tier, learned: learned, total: words.count)
    }

    func openTier(progress: [String: WordProgress]) throws -> TopTier {
        try dictionary.tierGate.openTier(progress: progress) { headwords in
            try userDatabase.hasAnswer(kind: .new, forAnyOf: headwords)
        }
    }
}
