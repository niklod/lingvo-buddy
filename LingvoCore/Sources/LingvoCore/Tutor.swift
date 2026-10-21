import Foundation
import Synchronization

/// The single entry point the app uses for learning logic and persistence.
public final class Tutor: Sendable {
    private let dictionary: DictionaryStore
    private let userDatabase: UserDatabase
    private let clock: any TutorClock
    private let cards: CardFactory
    private let deferrals = Mutex(CardDeferrals())

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
            decision = try pickCard(heldBack: deferrals.withLock { $0.heldBack(at: now) })
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
    private func pickCard(heldBack: Set<String>) throws -> CardDecision {
        let progress = try userDatabase.allProgress()
        let candidates = dictionary.quizEntries.filter { progress[$0.headword]?.status != .learned }
        guard let entry = candidates.first(where: { !heldBack.contains($0.headword) }) ?? candidates.first else {
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
