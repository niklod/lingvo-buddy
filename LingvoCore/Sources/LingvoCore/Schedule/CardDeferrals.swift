import Foundation

/// Words the learner put aside with "Later" or "×". Kept in memory only: a
/// 5-minute re-show does not need to survive an app restart.
struct CardDeferrals: Sendable, Equatable {
    static let laterDelay: TimeInterval = 5 * 60

    private struct Postponed: Sendable, Equatable {
        let card: Card
        let dueAt: Date
    }

    private var postponed: [Postponed] = []
    /// Held back from the very next card only, so "×" moves on to another word.
    private var skipped: Set<String> = []

    func postponing(_ card: Card, at now: Date) -> CardDeferrals {
        var copy = forgetting(card.headword)
        copy.postponed.append(Postponed(card: card, dueAt: now.addingTimeInterval(Self.laterDelay)))
        return copy
    }

    func skipping(_ card: Card) -> CardDeferrals {
        var copy = forgetting(card.headword)
        copy.skipped.insert(card.headword)
        return copy
    }

    /// The oldest postponed card whose 5 minutes are over.
    func dueCard(at now: Date) -> Card? {
        postponed.filter { $0.dueAt <= now }.min { $0.dueAt < $1.dueAt }?.card
    }

    /// Headwords the picker must not offer now.
    func heldBack(at now: Date) -> Set<String> {
        skipped.union(postponed.filter { $0.dueAt > now }.map(\.card.headword))
    }

    /// A card was shown: its word is no longer deferred, and the skip hold ends.
    func shown(_ card: Card) -> CardDeferrals {
        var copy = forgetting(card.headword)
        copy.skipped = []
        return copy
    }

    /// The word changed outside a card (row action, import): a kept snapshot would be stale.
    func forgetting(_ headword: String) -> CardDeferrals {
        var copy = self
        copy.postponed.removeAll { $0.card.headword == headword }
        copy.skipped.remove(headword)
        return copy
    }
}
