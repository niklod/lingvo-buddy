import Foundation

/// Decides which tier new words come from (spec: "After the Top‑1000 is fully
/// learned, the queue extends to ranks 1001–2000").
struct TierGate: Sendable {
    private let top1000Words: Set<String>
    private let top2000OnlyWords: Set<String>

    init(cardEntries: [DictionaryEntry]) {
        top1000Words = Set(cardEntries.filter { $0.rank <= TopTier.top1000.maxRank }.map(\.headword))
        top2000OnlyWords = Set(cardEntries.filter { TopTier.containing(rank: $0.rank) == .top2000 }.map(\.headword))
    }

    /// Once a Top‑2000 word was answered as a new word, the tier stays open: a
    /// failed review of a Top‑1000 word must not close it and flip the labels
    /// back. Only the picker hands out such cards, so quick-added words of
    /// those ranks (kind "mine") do not open it early.
    func openTier(
        progress: [String: WordProgress],
        answeredAsNew: (Set<String>) throws -> Bool
    ) rethrows -> TopTier {
        if top1000Words.allSatisfy({ progress[$0]?.status == .learned }) {
            return .top2000
        }
        let started = top2000OnlyWords.filter { progress[$0] != nil }
        guard !started.isEmpty else { return .top1000 }
        return try answeredAsNew(started) ? .top2000 : .top1000
    }
}
