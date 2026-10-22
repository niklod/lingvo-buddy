import Foundation

/// Where a looked-up word stands against the open tier: quick add shows
/// "Top‑2000 · #1460" for `.inside(.top2000)` and "outside Top‑1000" for `.outside(.top1000)`.
public enum TierMembership: Sendable, Equatable {
    case inside(TopTier)
    case outside(TopTier)
}

/// A dictionary entry found for quick add, with its tier line.
public struct WordLookup: Sendable, Equatable {
    public let entry: DictionaryEntry
    public let membership: TierMembership

    public init(entry: DictionaryEntry, membership: TierMembership) {
        self.entry = entry
        self.membership = membership
    }

    init(entry: DictionaryEntry, openTier open: TopTier) {
        let membership: TierMembership = if entry.rank <= open.maxRank, let tier = TopTier.containing(rank: entry.rank) {
            .inside(tier)
        } else {
            .outside(open)
        }
        self.init(entry: entry, membership: membership)
    }
}

extension Tutor {
    /// Finds a word of the bundled dictionary (all 10k ranks, quiz-excluded words
    /// too). Case and surrounding spaces are ignored; `nil` when the word is missing.
    public func lookup(_ text: String) throws -> WordLookup? {
        guard let entry = try dictionary.lookupEntry(text) else { return nil }
        return WordLookup(entry: entry, openTier: try openTier())
    }
}
