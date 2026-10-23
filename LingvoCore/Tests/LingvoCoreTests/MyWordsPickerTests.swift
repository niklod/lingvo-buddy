import Foundation
import LingvoCore
import Testing

@Suite("My words in the picker")
struct MyWordsPickerTests {
    private func add(_ text: String, _ translation: String, to learner: Learner) throws {
        _ = try learner.tutor.addMyWord(NewMyWord(text: text, translation: translation, example: nil))
    }

    @Test("my words come in the order they were added, before new words")
    func myWordsInAddedOrder() throws {
        let learner = try QuickAddTests.learner()
        try add("reluctant", "неохотный", to: learner)
        learner.clock.advance(by: Fixture.minute)
        try add("Kubernetes", "кубернетес", to: learner)

        let headwords = try (0..<3).map { _ in try learner.answerNext().card.headword }

        #expect(headwords == ["reluctant", "kubernetes", "they"])
    }

    @Test("a due learning word comes before a my word")
    func dueLearningBeforeMyWord() throws {
        let learner = try QuickAddTests.learner()
        try learner.answerNext(correctly: false)
        try add("reluctant", "неохотный", to: learner)

        let next = try learner.nextCard()

        #expect(next.headword == "they")
        #expect(next.kind == .new)
    }

    @Test("a my word still enters when the active-words limit is full")
    func myWordIgnoresActiveLimit() throws {
        let learner = try Learner(settings: LearningSettings(direction: .enToRu, maxActiveNewWords: 2))
        try learner.answerNext()
        try learner.answerNext()
        try add("reluctant", "неохотный", to: learner)

        #expect(try learner.nextCard().headword == "reluctant")
    }

    @Test("a my word in learning keeps the My word badge and the My words source")
    func myWordStaysMine() throws {
        let learner = try QuickAddTests.learner()
        try add("suggest", "предлагать", to: learner)
        try learner.answerNext(correctly: false)

        let again = try learner.nextCard()

        #expect(again.headword == "suggest")
        #expect(again.kind == .mine)
        #expect(again.source == .mine)
        #expect(again.mastery == 0)
    }

    @Test("a learned my word comes back as a review from My words")
    func learnedMyWordReview() throws {
        let learner = try QuickAddTests.learner()
        try add("reluctant", "неохотный", to: learner)
        #expect(try learner.learnNextWord() == "reluctant")
        learner.clock.advance(by: 8 * Fixture.day)

        let review = try learner.nextCard()

        #expect(review.headword == "reluctant")
        #expect(review.kind == .review)
        #expect(review.source == .mine)
    }
}
