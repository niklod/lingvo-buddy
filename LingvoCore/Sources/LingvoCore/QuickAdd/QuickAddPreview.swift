import Foundation

/// Where a word stands for the learner when quick add looks at it.
public enum WordStanding: Sendable, Equatable {
    /// Not started and not in My words: adding it is allowed. A queued
    /// dictionary word then moves to My words with priority.
    case notAdded
    /// Already in My words and not answered yet.
    case mine
    case learning(mastery: Int)
    case learned
}

/// An English word quick add can add, with what the panel shows for it.
public struct QuickAddCandidate: Sendable, Equatable {
    /// The dictionary headword, or the trimmed text for a word the dictionary lacks.
    public let headword: String
    /// `nil` when the dictionary does not know the word: a custom translation is then required.
    public let lookup: WordLookup?
    public let standing: WordStanding

    public init(headword: String, lookup: WordLookup?, standing: WordStanding) {
        self.headword = headword
        self.lookup = lookup
        self.standing = standing
    }

    public var canAdd: Bool { standing == .notAdded }
}

/// What the quick-add panel shows for the typed text, before the learner adds it.
public struct QuickAddPreview: Sendable, Equatable {
    /// Keeps the panel short; the best-ranked words are the usual ones.
    public static let maxCandidates = 5

    /// One word for English input. For Russian input, the English headwords whose
    /// dictionary translations contain the text, best rank first; the first is preselected.
    public let candidates: [QuickAddCandidate]
    /// The trimmed Russian text when the dictionary knows it: it becomes the
    /// card's translation. `nil` for English input and for unknown Russian text,
    /// which then needs a typed translation like any unknown word.
    public let russianText: String?

    public init(headword: String, lookup: WordLookup?, standing: WordStanding) {
        self.candidates = [QuickAddCandidate(headword: headword, lookup: lookup, standing: standing)]
        self.russianText = nil
    }

    public init(russianText: String, candidates: [QuickAddCandidate]) {
        precondition(!candidates.isEmpty, "Russian input without candidates takes the English path")
        self.candidates = candidates
        self.russianText = russianText
    }

    public var headword: String { preselected.headword }
    public var lookup: WordLookup? { preselected.lookup }
    public var standing: WordStanding { preselected.standing }
    public var canAdd: Bool { preselected.canAdd }

    private var preselected: QuickAddCandidate { candidates[0] }
}
