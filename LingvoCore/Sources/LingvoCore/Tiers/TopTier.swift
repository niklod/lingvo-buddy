import Foundation

/// A frequency tier the queue learns from: Top‑1000 first, then Top‑2000.
public enum TopTier: Int, Sendable, CaseIterable, Comparable {
    case top1000 = 1000
    case top2000 = 2000

    /// The highest frequency rank in the tier; also the "N" of the "Top‑N" label.
    public var maxRank: Int { rawValue }

    /// `nil` for ranks past the last tier: those words are for lookup only.
    public static func containing(rank: Int) -> TopTier? {
        guard rank >= 1 else { return nil }
        return allCases.first { rank <= $0.maxRank }
    }

    /// Words past this tier never become cards.
    static let last = TopTier.top2000

    public static func < (lhs: TopTier, rhs: TopTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

extension CardSource {
    /// The tier for the "Top‑N · #rank" label; `nil` for the learner's own words.
    public var topTier: TopTier? {
        switch self {
        case .rank(let rank): TopTier.containing(rank: rank)
        case .mine: nil
        }
    }
}

/// The progress card numbers: learned words of the open tier out of its card words.
public struct TierProgress: Sendable, Equatable {
    public let tier: TopTier
    public let learned: Int
    /// Words of ranks 1…`tier.maxRank` that can be cards (quiz-excluded words are not counted).
    public let total: Int

    public init(tier: TopTier, learned: Int, total: Int) {
        self.tier = tier
        self.learned = learned
        self.total = total
    }
}
