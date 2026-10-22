import Foundation
import LingvoCore
import Testing

@Suite("Tutor.answer")
struct AnswerTests {
    private let enToRu = LearningSettings(direction: .enToRu)

    @Test("a correct answer adds one mastery dot")
    func correctAnswerAddsDot() throws {
        let learner = try Learner(settings: enToRu)

        let (_, result) = try learner.answerNext()

        #expect(result.outcome == .correct)
        #expect(result.mastery == 1)
        #expect(result.correctAnswer == "они")
        #expect(result.becameLearned == false)
        #expect(result.isLearned == false)
    }

    @Test("a wrong answer reports the correct option and resets mastery to zero")
    func wrongAnswerResetsMastery() throws {
        let learner = try Learner(settings: enToRu)
        try learner.answerNext()
        learner.clock.advance(by: Fixture.hour)

        let (card, result) = try learner.answerNext(correctly: false)

        #expect(card.headword == "they")
        #expect(result.outcome == .wrong)
        #expect(result.mastery == 0)
        #expect(result.correctIndex == card.correctIndex)
        #expect(result.correctAnswer == "они")
    }

    @Test("\"Don't know\" counts as wrong")
    func dontKnowResetsMastery() throws {
        let learner = try Learner(settings: enToRu)
        try learner.answerNext()
        learner.clock.advance(by: Fixture.hour)
        let card = try learner.nextCard()

        let result = try learner.tutor.dontKnow(card)

        #expect(result.outcome == .dontKnow)
        #expect(result.mastery == 0)
        #expect(result.correctAnswer == "они")
    }

    @Test("a word answered wrong comes back on the next card")
    func wrongWordComesBack() throws {
        let learner = try Learner(settings: enToRu)
        try learner.answerNext(correctly: false)

        let next = try learner.nextCard()

        #expect(next.headword == "they")
        #expect(next.mastery == 0)
    }

    @Test("the next card for a word in progress shows its current mastery")
    func nextCardShowsCurrentMastery() throws {
        let learner = try Learner(settings: enToRu)
        try learner.answerNext()
        learner.clock.advance(by: Fixture.hour)

        let next = try learner.nextCard()

        #expect(next.headword == "they")
        #expect(next.mastery == 1)
    }

    @Test("mastery survives closing and reopening the user database")
    func masteryPersistsAcrossReopen() throws {
        let url = Fixture.temporaryDatabaseURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let clock = TestClock(Fixture.start)
        let firstSession = Learner(
            tutor: try Fixture.tutor(userDatabase: UserDatabase.open(at: url), clock: clock, settings: enToRu),
            clock: clock
        )
        for _ in 0..<2 {
            try firstSession.answerNext()
            clock.advance(by: Fixture.hour)
        }

        let secondSession = try Fixture.tutor(userDatabase: UserDatabase.open(at: url), clock: clock, settings: enToRu)
        let card = try #require(try secondSession.nextCard().card)

        #expect(card.headword == "they")
        #expect(card.mastery == 2)
    }

    @Test("a choice outside the four options is rejected")
    func invalidChoiceIsRejected() throws {
        let learner = try Learner()
        let card = try learner.nextCard()

        #expect(throws: LingvoCoreError.invalidChoice(4)) {
            try learner.tutor.answer(card, choice: 4)
        }
    }

    @Test("a card whose right option does not exist is refused, not a crash, and nothing is saved")
    func cardWithBadCorrectIndexIsRefused() throws {
        let learner = try Learner()
        let card = try learner.nextCard()
        let broken = Card(
            headword: card.headword, prompt: card.prompt, direction: card.direction, kind: card.kind,
            source: card.source, ipa: card.ipa, partOfSpeech: card.partOfSpeech, options: card.options,
            correctIndex: 7, example: card.example, mastery: card.mastery
        )

        #expect(throws: LingvoCoreError.invalidChoice(7)) { try learner.tutor.answer(broken, choice: 0) }
        #expect(throws: LingvoCoreError.invalidChoice(7)) { try learner.tutor.dontKnow(broken) }
        #expect(broken.correctAnswer == "")
        #expect(try learner.tutor.stats().todayAnswers == 0)
    }
}
