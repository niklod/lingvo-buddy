import Foundation
import LingvoCore
import Testing

@Suite("Reviews")
struct ReviewTests {
    /// Lets every due review through, so schedule tests do not depend on the cap.
    private let reviewsOnly = LearningSettings(reviewShare: 1)

    @Test("a learned word comes back as a review 7 days after it was learned")
    func reviewAfterSevenDays() throws {
        let learner = try Learner()
        let word = try learner.learnNextWord()
        learner.clock.advance(by: 7 * Fixture.day - Fixture.hour - Fixture.minute)
        let early = try learner.nextCard()
        learner.clock.advance(by: Fixture.minute)

        let review = try learner.nextCard()

        #expect(early.headword != word)
        #expect(review.headword == word)
        #expect(review.kind == .review)
        #expect(review.mastery == 4)
    }

    @Test("passed reviews come back after 21 days, then every 60 days")
    func reviewIntervalsGrow() throws {
        let learner = try Learner(settings: reviewsOnly)
        let word = try learner.learnNextWord()
        learner.clock.advance(by: 7 * Fixture.day - Fixture.hour)

        var dueAfterDays: [Int] = []
        for intervalDays in [21, 60, 60] {
            let (card, result) = try learner.answerNext()
            try #require(card.headword == word && card.kind == .review)
            #expect(result.isLearned && !result.becameLearned)
            learner.clock.advance(by: Double(intervalDays) * Fixture.day - Fixture.minute)
            let early = try learner.nextCard()
            learner.clock.advance(by: Fixture.minute)
            let due = try learner.nextCard()
            if early.headword != word, due.headword == word, due.kind == .review {
                dueAfterDays.append(intervalDays)
            }
        }

        #expect(dueAfterDays == [21, 60, 60])
    }

    @Test("a missed review sends the word back to learning with no dots")
    func missedReviewRelapses() throws {
        let learner = try Learner()
        let word = try learner.learnNextWord()
        learner.clock.advance(by: 7 * Fixture.day)

        let (review, result) = try learner.answerNext(correctly: false)
        let next = try learner.nextCard()

        #expect(review.kind == .review)
        #expect(result.mastery == 0)
        #expect(result.isLearned == false)
        #expect(next.headword == word)
        #expect(next.kind == .new)
        #expect(next.mastery == 0)
    }

    @Test("reviews take at most about 20% of cards when many are due")
    func reviewShareIsCapped() throws {
        let learner = try Learner()
        let learned = try (0..<5).map { _ in try learner.learnNextWord() }
        learner.clock.advance(by: 8 * Fixture.day)

        let kinds = try (0..<10).map { _ in try learner.answerNext().card.kind }

        #expect(Set(learned).count == 5)
        #expect(kinds.filter { $0 == .review }.count == 2)
    }

    @Test("a due review still comes when nothing else is left to practice")
    func reviewOverTheCapWhenNothingElse() throws {
        let tiny = try TestDictionary.make([
            .init("they", rank: 1, pos: "pronoun", ru: ["они"]),
            .init("know", rank: 2, pos: "verb", ru: ["знать"]),
            .init("year", rank: 3, pos: "noun", ru: ["год"]),
            .init("good", rank: 4, pos: "adjective", ru: ["хороший"]),
        ])
        let clock = TestClock(Fixture.start)
        let learner = Learner(tutor: try Fixture.tutor(dictionary: tiny, clock: clock), clock: clock)
        for _ in 0..<4 { try learner.learnNextWord() }
        learner.clock.advance(by: 8 * Fixture.day)
        try learner.answerNext()

        let next = try learner.nextCard()

        #expect(next.kind == .review)
    }
}
