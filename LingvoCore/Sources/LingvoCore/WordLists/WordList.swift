import Foundation

/// The lists of the Dictionary window sidebar. A my word is in My words and,
/// by its progress, also in Learning or Learned.
public enum WordList: String, Sendable, CaseIterable {
    /// Words in learning, and my words not answered yet: the picker shows
    /// those next, so for the learner they are already being learned.
    case learning
    case learned
    case myWords
    /// Card words of the open tier that were never answered, by rank.
    case queue
}

public struct LastAnswer: Sendable, Equatable {
    public let outcome: AnswerOutcome
    public let at: Date

    public init(outcome: AnswerOutcome, at: Date) {
        self.outcome = outcome
        self.at = at
    }
}

/// One row of the Dictionary window table.
public struct WordRow: Sendable, Equatable, Identifiable {
    /// Dots in the mastery column; a learned word has all of them.
    public static let masteryGoal = WordProgress.masteryGoal

    public let headword: String
    /// The learner's own translation if they set one, else the dictionary's first.
    public let translation: String
    public let mastery: Int
    public let lastAnswer: LastAnswer?
    /// `.mine` for my words, else the frequency rank.
    public let source: CardSource
    public let status: WordStatus?

    public var id: String { headword }

    public init(
        headword: String,
        translation: String,
        mastery: Int,
        lastAnswer: LastAnswer?,
        source: CardSource,
        status: WordStatus?
    ) {
        self.headword = headword
        self.translation = translation
        self.mastery = mastery
        self.lastAnswer = lastAnswer
        self.source = source
        self.status = status
    }

    /// A queued word has nothing to reset.
    public var canResetProgress: Bool { status != nil }
    public var canMarkLearned: Bool { status != .learned }
    /// Dictionary words cannot be deleted, only my words.
    public var canDelete: Bool { source == .mine }
}

/// What the Dictionary window shows for one list and search text.
public struct WordListPage: Sendable, Equatable {
    /// Rows of each list that match the search, so the sidebar shows where matches are.
    public let counts: [WordList: Int]
    /// The tier of the queue list ("Top‑1000 queue").
    public let queueTier: TopTier
    public let rows: [WordRow]

    public init(counts: [WordList: Int], queueTier: TopTier, rows: [WordRow]) {
        self.counts = counts
        self.queueTier = queueTier
        self.rows = rows
    }
}
