import Foundation
import LingvoCore
import Testing

@Suite("Practice while no word is due")
struct TooSoonTests {
    /// Three words in learning with the limit at three, answered a minute apart:
    /// no word is due and no new word may start.
    private func learnerWithNothingDue() throws -> Learner {
        let learner = try Learner(settings: LearningSettings(maxActiveNewWords: 3))
        for _ in 0..<3 {
            try learner.answerNext()
            learner.clock.advance(by: Fixture.minute)
        }
        return learner
    }

    @Test("with no word due, the cards rotate through the learning words")
    func fallbackRotates() throws {
        let learner = try learnerWithNothingDue()

        let headwords = try (0..<6).map { _ in
            let headword = try learner.answerNext().card.headword
            learner.clock.advance(by: Fixture.minute)
            return headword
        }

        #expect(headwords == ["they", "know", "think", "they", "know", "think"])
    }

    @Test("a card picked while no word is due is a practice card")
    func fallbackCardIsPractice() throws {
        let learner = try learnerWithNothingDue()

        let card = try learner.nextCard()

        #expect(card.isPractice)
    }

    @Test("new and due cards are not practice cards")
    func newAndDueCardsAreNotPractice() throws {
        let learner = try Learner()
        let fresh = try learner.answerNext().card
        learner.clock.advance(by: Fixture.hour)

        let due = try learner.nextCard()

        #expect(!fresh.isPractice)
        #expect(due.headword == fresh.headword)
        #expect(!due.isPractice)
    }

    @Test("a correct practice answer adds no dot and tells when the next word is due")
    func correctPracticeAnswerIsTooSoon() throws {
        let learner = try learnerWithNothingDue()

        let (card, result) = try learner.answerNext()

        #expect(card.headword == "they")
        #expect(result.outcome == .correct)
        #expect(result.mastery == 1)
        #expect(result.isTooSoon)
        #expect(result.nextDueAfterTooSoon == Fixture.start.addingTimeInterval(Fixture.hour))
    }

    @Test("a wrong practice answer counts as usual")
    func wrongPracticeAnswerIsNotTooSoon() throws {
        let learner = try learnerWithNothingDue()

        let result = try learner.answerNext(correctly: false).result

        #expect(result.mastery == 0)
        #expect(!result.isTooSoon)
    }

    @Test("a correct answer an hour after the last counted one is not too soon")
    func countedAnswerIsNotTooSoon() throws {
        let learner = try Learner()
        try learner.answerNext()
        learner.clock.advance(by: Fixture.hour)

        let result = try learner.answerNext().result

        #expect(result.mastery == 2)
        #expect(!result.isTooSoon)
    }
}
