import Foundation

/// A word chosen for the next card, before direction and options are decided.
struct PickedWord {
    let entry: DictionaryEntry
    let kind: CardKind
    let progress: WordProgress?
    /// Cards of my words show "My words" instead of the rank, also on reviews.
    var isMine = false
}

/// Chooses which word the next card shows (spec "Picker priority"):
/// due reviews within the review share, due learning words, my words not yet
/// started, then new words by rank while there is room among active words.
/// When none of these exist, an over-the-cap review or the learning word due
/// soonest keeps practice going.
struct WordPicker {
    let quizEntries: [DictionaryEntry]
    let settings: LearningSettings

    /// How many of the latest answers the review cap looks at (see `reviewAllowed`).
    /// The real share is 1 / (window + 1); rounding up keeps it at or below the setting.
    var reviewCapWindow: Int {
        guard settings.reviewShare > 0 else { return 0 }
        return max(Int((1 / settings.reviewShare).rounded(.up)) - 1, 0)
    }

    /// New words come only from the open `tier`. `myWords` are card entries of
    /// the learner's words, oldest first; they replace dictionary entries of the
    /// same headword. `heldBack` words ("Later", "×") are left out as if they
    /// were not in the dictionary.
    func pick(
        progress: [String: WordProgress],
        recentKinds: [CardKind?],
        now: Date,
        tier: TopTier,
        myWords: [DictionaryEntry] = [],
        heldBack: Set<String> = []
    ) -> PickedWord? {
        let mine = Set(myWords.map(\.headword))
        let candidates = quizEntries.filter { !mine.contains($0.headword) } + myWords
        // A held-back word is still active: counting it keeps "×" and "Later"
        // from opening a place for one more new word.
        let activeCount = candidates.filter { progress[$0.headword]?.status == .learning }.count
        let pool = candidates.filter { !heldBack.contains($0.headword) }
        let started = pool.compactMap { entry in progress[entry.headword].map { (entry, $0) } }
        let reviews = started
            .filter { $0.1.status == .learned && $0.1.isDue(at: now) }
            .sorted(by: Self.dueFirst)
        let learning = started
            .filter { $0.1.status == .learning }
            .sorted(by: Self.dueFirst)

        func picked(_ word: (DictionaryEntry, WordProgress), as kind: CardKind) -> PickedWord {
            let isMine = mine.contains(word.0.headword)
            return PickedWord(entry: word.0, kind: isMine && kind == .new ? .mine : kind, progress: word.1, isMine: isMine)
        }

        if let review = reviews.first, reviewAllowed(recentKinds: recentKinds) {
            return picked(review, as: .review)
        }
        if let due = learning.first(where: { $0.1.isDue(at: now) }) {
            return picked(due, as: .new)
        }
        if let fresh = pool.first(where: { mine.contains($0.headword) && progress[$0.headword] == nil }) {
            return PickedWord(entry: fresh, kind: .mine, progress: nil, isMine: true)
        }
        if activeCount < settings.maxActiveNewWords,
           let fresh = pool.first(where: { !mine.contains($0.headword) && $0.rank <= tier.maxRank && progress[$0.headword] == nil }) {
            return PickedWord(entry: fresh, kind: .new, progress: nil)
        }
        if let review = reviews.first {
            return picked(review, as: .review)
        }
        return learning.first.map { picked($0, as: .new) }
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
