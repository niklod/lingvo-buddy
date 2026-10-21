import Foundation
import LingvoCore
import Testing

@Suite("Quick add duplicates")
struct QuickAddDuplicateTests {
    @discardableResult
    private func add(_ text: String, _ translation: String, to learner: Learner, example: String? = nil) throws -> AddWordOutcome {
        try learner.tutor.addMyWord(NewMyWord(text: text, translation: translation, example: example))
    }

    @Test("a queued word moves to My words with priority, keeps its rank, takes my translation and example")
    func queuedWordMovesToMyWords() throws {
        let learner = try QuickAddTests.learner()

        let outcome = try add("suggest", "советовать", to: learner, example: "I suggest we start again tomorrow.")
        let card = try learner.nextCard()

        #expect(outcome == .added(headword: "suggest"))
        #expect(card.headword == "suggest")
        #expect(card.kind == .mine)
        #expect(card.source == .mine)
        #expect(card.correctAnswer == "советовать")
        #expect(card.example == "I suggest we start again tomorrow.")
        #expect(try learner.tutor.quickAddPreview("suggest")?.lookup?.entry.rank == 470)
        #expect(try learner.tutor.quickAddPreview("suggest")?.standing == .mine)
    }

    @Test("a moved word is not shown again as a new word")
    func movedWordIsNotDuplicated() throws {
        let learner = try QuickAddTests.learner()
        try add("they", "они сами", to: learner)
        try learner.answerNext()

        let next = try (0..<3).map { _ in try learner.answerNext().card }

        #expect(next.map(\.headword) == ["know", "think", "year"])
    }

    @Test("a word in learning shows its status and is not added again")
    func learningWordShowsStatus() throws {
        let learner = try QuickAddTests.learner()
        try learner.answerNext()

        let preview = try #require(try learner.tutor.quickAddPreview("They"))
        let outcome = try add("they", "они", to: learner)

        #expect(preview.standing == .learning(mastery: 1))
        #expect(!preview.canAdd)
        #expect(outcome == .alreadyAdded(.learning(mastery: 1)))
        #expect(try learner.tutor.stats().myWordsCount == 0)
    }

    @Test("a learned word shows its status and is not added again")
    func learnedWordShowsStatus() throws {
        let learner = try QuickAddTests.learner()
        let learned = try learner.learnNextWord()

        #expect(try learner.tutor.quickAddPreview(learned)?.standing == .learned)
        #expect(try add(learned, "они", to: learner) == .alreadyAdded(.learned))
    }

    @Test("a word already in My words is not added twice, whatever its case")
    func myWordIsNotAddedTwice() throws {
        let learner = try QuickAddTests.learner()
        try add("Kubernetes", "кубернетес", to: learner)
        try add("reluctant", "неохотный", to: learner)

        #expect(try add("kubernetes", "кубер", to: learner) == .alreadyAdded(.mine))
        #expect(try add("RELUCTANT", "нежелающий", to: learner) == .alreadyAdded(.mine))
        #expect(try learner.tutor.quickAddPreview("KUBERNETES")?.headword == "Kubernetes")
        #expect(try learner.tutor.stats().myWordsCount == 2)
    }

    @Test("an answered my word in learning shows its learning status")
    func answeredMyWordIsLearning() throws {
        let learner = try QuickAddTests.learner()
        try add("reluctant", "неохотный", to: learner)
        try learner.answerNext(correctly: false)

        #expect(try add("reluctant", "неохотный", to: learner) == .alreadyAdded(.learning(mastery: 0)))
    }

    @Test("blank or too long input is rejected with a clear error")
    func invalidInput() throws {
        let learner = try QuickAddTests.learner()
        let long = String(repeating: "a", count: NewMyWord.maxWordLength + 1)

        #expect(throws: LingvoCoreError.emptyWord) { try add("  ", "что-то", to: learner) }
        #expect(throws: LingvoCoreError.tooLong(.word, limit: NewMyWord.maxWordLength)) {
            try add(long, "что-то", to: learner)
        }
        #expect(try learner.tutor.quickAddPreview(" \n ") == nil)
    }
}
