import Foundation
import LingvoCore
import Testing

@Suite("Word picker")
struct PickerTests {
    @Test("new words come in frequency-rank order")
    func newWordsByRank() throws {
        let learner = try Learner()

        let headwords = try (0..<4).map { _ in try learner.answerNext().card.headword }

        #expect(headwords == ["they", "know", "think", "year"])
    }

    @Test("a due learning word comes before a new word")
    func dueLearningBeforeNew() throws {
        let learner = try Learner()
        try learner.answerNext()
        try learner.answerNext()
        learner.clock.advance(by: Fixture.hour)

        let next = try learner.nextCard()

        #expect(next.headword == "they")
        #expect(next.kind == .new)
        #expect(next.mastery == 1)
    }

    @Test("no new word enters while 10 words are in learning")
    func maxActiveNewWordsByDefault() throws {
        let learner = try Learner()
        let started = try (0..<10).map { _ in try learner.answerNext().card.headword }

        let next = try learner.nextCard()

        #expect(Set(started).count == 10)
        #expect(started.contains(next.headword))
    }

    @Test("the active new words limit follows the setting")
    func maxActiveNewWordsIsConfigurable() throws {
        let learner = try Learner(settings: LearningSettings(maxActiveNewWords: 3))
        let started = try (0..<3).map { _ in try learner.answerNext().card.headword }

        let next = try learner.nextCard()

        #expect(started == ["they", "know", "think"])
        #expect(started.contains(next.headword))
    }

    @Test("a learned word frees a place for a new word")
    func learnedWordFreesActivePlace() throws {
        let learner = try Learner(settings: LearningSettings(maxActiveNewWords: 1))
        try learner.learnNextWord()

        let next = try learner.nextCard()

        #expect(next.headword == "know")
    }
}

@Suite("Card direction")
struct DirectionTests {
    @Test("the EN → RU setting shows the English word and Russian options")
    func enToRuSetting() throws {
        let directions = try (1...20).map { seed in
            try Learner(settings: LearningSettings(direction: .enToRu), seed: UInt64(seed)).nextCard().direction
        }

        #expect(Set(directions) == [.enToRu])
    }

    @Test("the RU → EN setting shows the Russian word and English options")
    func ruToEnSetting() throws {
        let learner = try Learner(settings: LearningSettings(direction: .ruToEn))

        let card = try learner.nextCard()

        #expect(card.direction == .ruToEn)
        #expect(card.prompt == "они")
        #expect(card.correctAnswer == "they")
        #expect(card.options.allSatisfy { $0.unicodeScalars.allSatisfy(\.isASCII) })
    }

    @Test("Mix shows about 70% EN → RU cards for new words")
    func mixSetting() throws {
        let directions = try (1...200).map { seed in
            try Learner(seed: UInt64(seed)).nextCard().direction
        }
        let enToRuShare = Double(directions.filter { $0 == .enToRu }.count) / Double(directions.count)

        #expect((0.6...0.8).contains(enToRuShare))
    }
}
