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

/// What the quick-add panel shows for the typed text, before the learner adds it.
public struct QuickAddPreview: Sendable, Equatable {
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
