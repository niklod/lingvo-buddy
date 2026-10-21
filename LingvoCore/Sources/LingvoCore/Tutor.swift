import Foundation

/// The single entry point the app uses for learning logic and persistence.
public final class Tutor: Sendable {
    private let dictionary: DictionaryStore
    private let userDatabase: UserDatabase
    private let clock: any TutorClock
    private let cards: CardFactory

    public init(
        dictionary: DictionaryStore,
        userDatabase: UserDatabase,
        clock: any TutorClock = SystemClock(),
        random: any RandomSource = SystemRandomSource()
    ) {
        self.dictionary = dictionary
        self.userDatabase = userDatabase
        self.clock = clock
        self.cards = CardFactory(quizEntries: dictionary.quizEntries, random: random)
    }

    public func nextCard(context: CardContext = CardContext()) throws -> CardDecision {
        let progress = try userDatabase.allProgress()
        guard let entry = dictionary.quizEntries.first(where: { progress[$0.headword]?.status != .learned }) else {
            return .noCard(.noWordsAvailable)
        }
        return .card(try cards.card(for: entry, progress: progress[entry.headword]))
    }

    public func answer(_ card: Card, choice: Int) throws -> AnswerResult {
        guard card.options.indices.contains(choice) else {
            throw LingvoCoreError.invalidChoice(choice)
        }
        return try record(choice == card.correctIndex ? .correct : .wrong, for: card)
    }

    /// "Don't know" counts as a wrong answer.
    public func dontKnow(_ card: Card) throws -> AnswerResult {
        try record(.dontKnow, for: card)
    }

    private func record(_ outcome: AnswerOutcome, for card: Card) throws -> AnswerResult {
        guard try dictionary.entry(headword: card.headword) != nil else {
            throw LingvoCoreError.unknownWord(card.headword)
        }
        let now = clock.now()
        let before = try userDatabase.progress(for: card.headword) ?? .fresh(card.headword)
        let after = before.applying(outcome, at: now)
        try userDatabase.record(
            AnswerRecord(headword: card.headword, direction: card.direction, result: outcome, answeredAt: now),
            updating: after
        )
        return AnswerResult(
            outcome: outcome,
            correctIndex: card.correctIndex,
            correctAnswer: card.correctAnswer,
            becameLearned: before.status != .learned && after.status == .learned,
            mastery: after.mastery
        )
    }
}
