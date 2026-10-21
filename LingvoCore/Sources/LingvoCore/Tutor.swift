import Foundation

/// The single entry point the app uses for learning logic and persistence.
public final class Tutor: Sendable {
    private let dictionary: DictionaryStore
    private let userDatabase: UserDatabase
    private let clock: any TutorClock
    private let picker: WordPicker
    private let cards: CardFactory

    public init(
        dictionary: DictionaryStore,
        userDatabase: UserDatabase,
        clock: any TutorClock = SystemClock(),
        random: any RandomSource = SystemRandomSource(),
        settings: LearningSettings = LearningSettings()
    ) {
        self.dictionary = dictionary
        self.userDatabase = userDatabase
        self.clock = clock
        self.picker = WordPicker(quizEntries: dictionary.quizEntries, settings: settings)
        self.cards = CardFactory(
            directions: DirectionChooser(setting: settings.direction, random: random),
            distractors: DistractorPicker(quizEntries: dictionary.quizEntries, random: random),
            random: random
        )
    }

    public func nextCard(context: CardContext = CardContext()) throws -> CardDecision {
        let picked = picker.pick(
            progress: try userDatabase.allProgress(),
            recentKinds: try userDatabase.recentAnswerKinds(limit: picker.reviewCapWindow),
            now: clock.now()
        )
        guard let picked else {
            return .noCard(.noWordsAvailable)
        }
        return .card(try cards.card(for: picked))
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
        let after = before.applying(outcome, direction: card.direction, at: now)
        try userDatabase.record(
            AnswerRecord(
                headword: card.headword,
                direction: card.direction,
                kind: card.kind,
                result: outcome,
                answeredAt: now
            ),
            updating: after
        )
        return AnswerResult(
            outcome: outcome,
            correctIndex: card.correctIndex,
            correctAnswer: card.correctAnswer,
            becameLearned: before.status != .learned && after.status == .learned,
            isLearned: after.status == .learned,
            mastery: after.mastery
        )
    }
}
