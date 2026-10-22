import Foundation
import LingvoCore
import Testing

@Suite("Tutor.nextCard")
struct NextCardTests {
    @Test("a fresh learner gets the most frequent quiz word as a new EN→RU card")
    func freshLearnerGetsMostFrequentWord() throws {
        let tutor = try Fixture.tutor(settings: LearningSettings(direction: .enToRu))

        let card = try #require(try tutor.nextCard().card)

        #expect(card.headword == "they")
        #expect(card.prompt == "they")
        #expect(card.direction == .enToRu)
        #expect(card.kind == .new)
        #expect(card.source == .rank(20))
        #expect(card.ipa == "/ðeɪ/")
        #expect(card.partOfSpeech == .pronoun)
        #expect(card.example == "They live next door.")
        #expect(card.russianExample == "Они живут по соседству.")
        #expect(card.mastery == 0)
    }

    @Test("the card has the correct translation and three different distractors")
    func cardHasCorrectAnswerAndThreeDistractors() throws {
        let tutor = try Fixture.tutor(settings: LearningSettings(direction: .enToRu))

        let card = try #require(try tutor.nextCard().card)

        #expect(card.options.count == 4)
        #expect(Set(card.options).count == 4)
        #expect(card.options[card.correctIndex] == "они")
        #expect(card.correctAnswer == "они")
    }

    @Test("the correct option position depends on the random source, not a fixed slot")
    func correctOptionPositionVaries() throws {
        let positions = try (1...12).map { seed in
            try #require(try Fixture.tutor(seed: UInt64(seed)).nextCard().card).correctIndex
        }

        #expect(Set(positions).count > 1)
    }

    @Test("an empty quiz tier gives no card with a reason")
    func emptyDictionaryGivesNoCard() throws {
        let lookupOnly = Data("""
        {"entries": [{"headword": "reluctant", "rank": 4870, "pos": "adjective", "ipa": "/rɪˈlʌktənt/",
          "example": null, "synonym_group": null, "tier": "lookup", "translations": {"ru": ["неохотный"]}}]}
        """.utf8)
        let tutor = try Tutor(
            dictionary: try DictionaryStore.inMemory(fromJSON: [lookupOnly]),
            userDatabase: try UserDatabase.inMemory(),
            clock: TestClock(Fixture.start),
            random: SeededRandomSource(seed: 1)
        )

        #expect(try tutor.nextCard() == .noCard(.noWordsAvailable))
    }
}
