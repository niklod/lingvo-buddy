import Foundation
import LingvoCore
import Testing

@Suite("Tutor.answer")
struct AnswerTests {
    @Test("a correct answer adds one mastery dot")
    func correctAnswerAddsDot() throws {
        let tutor = try Fixture.tutor()
        let card = try #require(try tutor.nextCard().card)

        let result = try tutor.answer(card, choice: card.correctIndex)

        #expect(result.outcome == .correct)
        #expect(result.mastery == 1)
        #expect(result.correctAnswer == "они")
        #expect(result.becameLearned == false)
    }

    @Test("a wrong answer reports the correct option and resets mastery to zero")
    func wrongAnswerResetsMastery() throws {
        let tutor = try Fixture.tutor()
        let first = try #require(try tutor.nextCard().card)
        _ = try tutor.answer(first, choice: first.correctIndex)
        let second = try #require(try tutor.nextCard().card)

        let result = try tutor.answer(second, choice: wrongChoice(on: second))

        #expect(result.outcome == .wrong)
        #expect(result.mastery == 0)
        #expect(result.correctIndex == second.correctIndex)
        #expect(result.correctAnswer == "они")
    }

    @Test("\"Don't know\" counts as wrong")
    func dontKnowResetsMastery() throws {
        let tutor = try Fixture.tutor()
        let first = try #require(try tutor.nextCard().card)
        _ = try tutor.answer(first, choice: first.correctIndex)
        let second = try #require(try tutor.nextCard().card)

        let result = try tutor.dontKnow(second)

        #expect(result.outcome == .dontKnow)
        #expect(result.mastery == 0)
        #expect(result.correctAnswer == "они")
    }

    @Test("the next card for a word in progress shows its current mastery")
    func nextCardShowsCurrentMastery() throws {
        let tutor = try Fixture.tutor()
        let first = try #require(try tutor.nextCard().card)
        _ = try tutor.answer(first, choice: first.correctIndex)

        let next = try #require(try tutor.nextCard().card)

        #expect(next.headword == "they")
        #expect(next.mastery == 1)
    }

    @Test("mastery survives closing and reopening the user database")
    func masteryPersistsAcrossReopen() throws {
        let url = Fixture.temporaryDatabaseURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let firstSession = try Fixture.tutor(userDatabase: UserDatabase.open(at: url))
        for _ in 0..<2 {
            let card = try #require(try firstSession.nextCard().card)
            _ = try firstSession.answer(card, choice: card.correctIndex)
        }

        let secondSession = try Fixture.tutor(userDatabase: UserDatabase.open(at: url))
        let card = try #require(try secondSession.nextCard().card)

        #expect(card.headword == "they")
        #expect(card.mastery == 2)
    }

    @Test("four correct answers make the word learned and the next card moves on")
    func fourCorrectAnswersLearnTheWord() throws {
        let tutor = try Fixture.tutor()
        var results: [AnswerResult] = []
        for _ in 0..<4 {
            let card = try #require(try tutor.nextCard().card)
            results.append(try tutor.answer(card, choice: card.correctIndex))
        }

        let next = try #require(try tutor.nextCard().card)

        #expect(results.map(\.mastery) == [1, 2, 3, 4])
        #expect(results.map(\.becameLearned) == [false, false, false, true])
        #expect(next.headword == "know")
    }

    @Test("a choice outside the four options is rejected")
    func invalidChoiceIsRejected() throws {
        let tutor = try Fixture.tutor()
        let card = try #require(try tutor.nextCard().card)

        #expect(throws: LingvoCoreError.invalidChoice(4)) {
            try tutor.answer(card, choice: 4)
        }
    }

    private func wrongChoice(on card: Card) -> Int {
        (card.correctIndex + 1) % card.options.count
    }
}
