import Foundation

/// A word chosen for the next card, before direction and options are decided.
struct PickedWord {
    let entry: DictionaryEntry
    let kind: CardKind
    let progress: WordProgress?
}

/// Chooses which word the next card shows (spec "Picker priority"):
/// due reviews within the review share, due learning words, new words by rank
/// while there is room among active words. When none of these exist, an
/// over-the-cap review or the learning word due soonest keeps practice going.
struct WordPicker {
    let quizEntries: [DictionaryEntry]
    let settings: LearningSettings

    /// How many of the latest answers the review cap looks at (see `reviewAllowed`).
    var reviewCapWindow: Int {
        guard settings.reviewShare > 0 else { return 0 }
        return max(Int((1 / settings.reviewShare).rounded()) - 1, 0)
    }

    /// New words come only from the open `tier`. `heldBack` words ("Later", "×")
    /// are left out as if they were not in the dictionary.
    func pick(
        progress: [String: WordProgress],
        recentKinds: [CardKind?],
        now: Date,
        tier: TopTier,
        heldBack: Set<String> = []
    ) -> PickedWord? {
        let quizEntries = heldBack.isEmpty ? quizEntries : quizEntries.filter { !heldBack.contains($0.headword) }
        let started = quizEntries.compactMap { entry in progress[entry.headword].map { (entry, $0) } }
        let reviews = started
            .filter { $0.1.status == .learned && $0.1.isDue(at: now) }
            .sorted(by: Self.dueFirst)
        let learning = started
            .filter { $0.1.status == .learning }
            .sorted(by: Self.dueFirst)

        if let review = reviews.first, reviewAllowed(recentKinds: recentKinds) {
            return PickedWord(entry: review.0, kind: .review, progress: review.1)
        }
        if let due = learning.first(where: { $0.1.isDue(at: now) }) {
            return PickedWord(entry: due.0, kind: .new, progress: due.1)
        }
        if learning.count < settings.maxActiveNewWords,
           let fresh = quizEntries.first(where: { $0.rank <= tier.maxRank && progress[$0.headword] == nil }) {
            return PickedWord(entry: fresh, kind: .new, progress: nil)
        }
        if let review = reviews.first {
            return PickedWord(entry: review.0, kind: .review, progress: review.1)
        }
        return learning.first.map { PickedWord(entry: $0.0, kind: .new, progress: $0.1) }
    }

    /// Spreads reviews evenly: with a 20% share at least four other cards
    /// come between two reviews, so a backlog of due reviews never takes over.
    private func reviewAllowed(recentKinds: [CardKind?]) -> Bool {
        guard settings.reviewShare > 0 else { return false }
        return !recentKinds.prefix(reviewCapWindow).contains(.review)
    }

    private static func dueFirst(_ lhs: (DictionaryEntry, WordProgress), _ rhs: (DictionaryEntry, WordProgress)) -> Bool {
        let left = lhs.1.dueAt ?? .distantPast
        let right = rhs.1.dueAt ?? .distantPast
        return left == right ? lhs.0.rank < rhs.0.rank : left < right
    }
}
