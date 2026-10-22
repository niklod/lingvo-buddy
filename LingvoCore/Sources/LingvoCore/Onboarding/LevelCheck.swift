import Foundation

/// The words onboarding asks "Know / Don't know" about.
public struct LevelCheckSample: Sendable, Equatable {
    /// "About 30 words" (spec): enough to place the learner, short enough to finish.
    public static let defaultSize = 30

    /// The tier the words come from (the "Top‑N" of the onboarding text).
    public let tier: TopTier
    /// Easiest (lowest rank) first.
    public let words: [DictionaryEntry]

    public init(tier: TopTier, words: [DictionaryEntry]) {
        self.tier = tier
        self.words = words
    }
}

public struct LevelCheckAnswer: Sendable, Equatable {
    public let headword: String
    public let knows: Bool

    public init(headword: String, knows: Bool) {
        self.headword = headword
        self.knows = knows
    }
}

/// What applying a level check changed, for the onboarding summary line.
public struct LevelCheckOutcome: Sendable, Equatable {
    /// Words marked learned: the known sample words and the easier words below the level.
    public let learnedCount: Int
    /// The rank up to which unasked words count as known; `nil` when no level was found.
    public let levelRank: Int?

    public init(learnedCount: Int, levelRank: Int?) {
        self.learnedCount = learnedCount
        self.levelRank = levelRank
    }
}

/// Stratified sampling: the ranked words are cut into equal bands and one
/// random word comes from each band, so the sample covers the whole tier and
/// still differs from one install to the next.
enum LevelCheckSampler {
    static func sample(from ranked: [DictionaryEntry], size: Int, random: any RandomSource) -> [DictionaryEntry] {
        guard size > 0 else { return [] }
        guard ranked.count > size else { return ranked }
        return (0..<size).map { band in
            let start = band * ranked.count / size
            let end = (band + 1) * ranked.count / size
            return ranked[start + random.nextInt(below: end - start)]
        }
    }
}
