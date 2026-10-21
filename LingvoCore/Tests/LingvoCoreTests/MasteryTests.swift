import Foundation
import LingvoCore
import Testing

@Suite("Mastery rules")
struct MasteryTests {
    @Test("a correct answer within 1 h of the last counted one does not add a dot")
    func quickRepeatDoesNotCount() throws {
        let learner = try Learner()
        let (first, _) = try learner.answerNext()
        learner.clock.advance(by: 59 * Fixture.minute)

        let result = try learner.tutor.answer(first, choice: first.correctIndex)

        #expect(result.outcome == .correct)
        #expect(result.mastery == 1)
    }

    @Test("a correct answer 1 h after the last counted one adds a dot")
    func answerAfterOneHourCounts() throws {
        let learner = try Learner()
        let (first, _) = try learner.answerNext()
        learner.clock.advance(by: 30 * Fixture.minute)
        _ = try learner.tutor.answer(first, choice: first.correctIndex)
        learner.clock.advance(by: 30 * Fixture.minute)

        let (second, result) = try learner.answerNext()

        #expect(second.headword == "they")
        #expect(result.mastery == 2)
    }

    @Test("four counted correct answers in both directions make the word learned")
    func fourCorrectAnswersLearnTheWord() throws {
        let learner = try Learner()
        var answers: [(card: Card, result: AnswerResult)] = []
        for _ in 0..<4 {
            answers.append(try learner.answerNext())
            learner.clock.advance(by: Fixture.hour)
        }

        #expect(answers.map(\.card.headword) == ["they", "they", "they", "they"])
        #expect(answers.map(\.result.mastery) == [1, 2, 3, 4])
        #expect(answers.map(\.result.becameLearned) == [false, false, false, true])
        #expect(answers.last?.result.isLearned == true)
        #expect(Set(answers.map(\.card.direction)) == [.enToRu, .ruToEn])
    }

    @Test("after a word is learned the next card moves on to the next word")
    func learnedWordLeavesTheQueue() throws {
        let learner = try Learner()
        try learner.learnNextWord()

        let next = try learner.nextCard()

        #expect(next.headword == "know")
        #expect(next.kind == .new)
    }

    @Test("one dot short with a direction missing, the next card is forced to that direction")
    func missingDirectionIsForced() throws {
        let learner = try Learner(settings: LearningSettings(direction: .enToRu))
        for _ in 0..<3 {
            try learner.answerNext()
            learner.clock.advance(by: Fixture.hour)
        }

        let forced = try learner.nextCard()

        #expect(forced.headword == "they")
        #expect(forced.direction == .ruToEn)
        #expect(forced.prompt == "они")
        #expect(forced.correctAnswer == "they")
        #expect(forced.mastery == 3)
    }

    @Test("the last dot does not count while a direction is missing")
    func lastDotNeedsBothDirections() throws {
        let learner = try Learner(settings: LearningSettings(direction: .enToRu))
        var lastCard: Card?
        for _ in 0..<3 {
            lastCard = try learner.answerNext().card
            learner.clock.advance(by: Fixture.hour)
        }
        let staleEnToRuCard = try #require(lastCard)

        let result = try learner.tutor.answer(staleEnToRuCard, choice: staleEnToRuCard.correctIndex)

        #expect(result.mastery == 3)
        #expect(result.isLearned == false)
        #expect(try learner.nextCard().direction == .ruToEn)
    }
}
