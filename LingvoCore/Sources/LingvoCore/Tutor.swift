import Foundation
import Synchronization

/// The single entry point the app uses for learning logic and persistence.
public final class Tutor: Sendable {
    let dictionary: DictionaryStore
    let userDatabase: UserDatabase
    let clock: any TutorClock
    private let picker: WordPicker
    private let cards: CardFactory
    private let deferrals = Mutex(CardDeferrals())

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

    /// A card that "Later" postponed comes first once its 5 minutes are over.
    public func nextCard(context: CardContext = CardContext()) throws -> CardDecision {
        let now = clock.now()
        if let reason = context.holdReason(at: now) {
            return .noCard(reason)
        }
        let decision: CardDecision
        if let postponed = deferrals.withLock({ $0.dueCard(at: now) }) {
            decision = .card(postponed)
        } else {
            decision = try pickCard(heldBack: deferrals.withLock { $0.heldBack(at: now) }, now: now)
        }
        if let card = decision.card {
            deferrals.withLock { $0 = $0.shown(card) }
        }
        return decision
    }

    /// "Later": the same card comes back in 5 minutes. Not an answer: no stat changes.
    public func later(_ card: Card) {
        let now = clock.now()
        deferrals.withLock { $0 = $0.postponing(card, at: now) }
    }

    /// "×" or Esc: the next card is another word. Not an answer: no stat changes.
    public func skip(_ card: Card) {
        deferrals.withLock { $0 = $0.skipping(card) }
    }

    /// A held-back word is still offered when nothing else is left.
    private func pickCard(heldBack: Set<String>, now: Date) throws -> CardDecision {
        let progress = try userDatabase.allProgress()
        let recentKinds = try userDatabase.recentAnswerKinds(limit: picker.reviewCapWindow)
        let tier = try openTier(progress: progress)
        let myWords = try myWordEntries()
        let picked = picker.pick(
            progress: progress, recentKinds: recentKinds, now: now, tier: tier, myWords: myWords, heldBack: heldBack
        ) ?? picker.pick(progress: progress, recentKinds: recentKinds, now: now, tier: tier, myWords: myWords)
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
        guard try dictionary.entry(headword: card.headword) != nil
                || userDatabase.myWord(headword: card.headword) != nil else {
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
