import Foundation
import LingvoCore
import Testing

/// Drives a tutor like a learner would: takes the next card and answers it.
struct Learner {
    let tutor: Tutor
    let clock: TestClock

    init(settings: LearningSettings = LearningSettings(), seed: UInt64 = 1) throws {
        let clock = TestClock(Fixture.start)
        self.clock = clock
        self.tutor = try Fixture.tutor(clock: clock, seed: seed, settings: settings)
    }

    init(tutor: Tutor, clock: TestClock) {
        self.tutor = tutor
        self.clock = clock
    }

    func nextCard() throws -> Card {
        try #require(try tutor.nextCard().card)
    }

    @discardableResult
    func answerNext(correctly: Bool = true) throws -> (card: Card, result: AnswerResult) {
        let card = try nextCard()
        let choice = correctly ? card.correctIndex : (card.correctIndex + 1) % card.options.count
        return (card, try tutor.answer(card, choice: choice))
    }

    /// Answers one hour apart: a correct answer within the hour after the last
    /// counted one adds no dot, so a faster loop would never learn the word.
    @discardableResult
    func learnNextWord() throws -> String {
        let headword = try nextCard().headword
        for _ in 0..<8 {
            let (card, result) = try answerNext()
            try #require(card.headword == headword)
            clock.advance(by: Fixture.hour)
            if result.becameLearned { return headword }
        }
        Issue.record("\(headword) was not learned after 8 correct answers")
        return headword
    }
}
