import Foundation
import LingvoCore
import Testing

@Suite("Quick add from Russian")
struct QuickAddRussianTests {
    private func candidates(_ text: String, learner: Learner) throws -> [String] {
        try learner.tutor.quickAddPreview(text)?.candidates.map(\.headword) ?? []
    }

    @Test("a Russian word lists the English headwords that translate to it, best rank first")
    func russianWordListsCandidates() throws {
        let learner = try QuickAddTests.learner()

        let preview = try #require(try learner.tutor.quickAddPreview(" предлагать "))

        let expected = QuickAddPreview(russianText: "предлагать", candidates: try ["offer", "suggest", "propose"].map {
            QuickAddCandidate(headword: $0, lookup: try learner.tutor.lookup($0), standing: .notAdded)
        })
        #expect(preview == expected)
    }

    @Test("at most 5 candidates, sorted by rank and not by dictionary order")
    func candidatesAreLimitedAndRanked() throws {
        let learner = try QuickAddTests.learner()

        #expect(try candidates("быстрый", learner: learner) == ["rapid", "prompt", "swift", "brisk", "speedy"])
    }

    @Test("case and «ё» do not change the candidates, on either side of the match")
    func caseAndYoAreIgnored() throws {
        let learner = try QuickAddTests.learner()
        let expected = ["lightweight", "effortless", "airy"]

        #expect(try candidates("лёгкий", learner: learner) == expected)
        #expect(try candidates("легкий", learner: learner) == expected)
        #expect(try candidates("ЛЁГКИЙ", learner: learner) == expected)
        #expect(try candidates("Сомнение", learner: learner) == ["doubt", "hesitation"])
        #expect(try candidates("сомнение", learner: learner) == ["doubt", "hesitation"])
    }

    @Test("Latin and mixed text keep the English path")
    func latinAndMixedTextStayEnglish() throws {
        let learner = try QuickAddTests.learner()

        let latin = try #require(try learner.tutor.quickAddPreview("Rapid"))
        let mixed = try #require(try learner.tutor.quickAddPreview("rapid быстрый"))

        #expect(latin.russianText == nil)
        #expect(latin.candidates.map(\.headword) == ["rapid"])
        #expect(latin.lookup?.entry.rank == 2300)
        #expect(mixed.russianText == nil)
        #expect(mixed.headword == "rapid быстрый")
        #expect(mixed.lookup == nil)
    }

    @Test("a Russian word with no candidates needs a typed translation, as an unknown word")
    func unknownRussianWord() throws {
        let learner = try QuickAddTests.learner()

        let preview = try #require(try learner.tutor.quickAddPreview(" медленно "))

        #expect(preview == QuickAddPreview(headword: "медленно", lookup: nil, standing: .notAdded, isRussianInput: true))
    }

    @Test("the preview tells Russian text from English, with or without candidates")
    func previewKnowsTheTypedLanguage() throws {
        let learner = try QuickAddTests.learner()

        #expect(try learner.tutor.quickAddPreview("медленно")?.isRussianInput == true)
        #expect(try learner.tutor.quickAddPreview("сомнение")?.isRussianInput == true)
        #expect(try learner.tutor.quickAddPreview("kubernetes")?.isRussianInput == false)
        #expect(try learner.tutor.quickAddPreview("rapid быстрый")?.isRussianInput == false)
    }

    @Test("a machine-suggested English word for unknown Russian text asks the typed Russian word")
    func machineSuggestionForRussianBecomesCard() throws {
        let learner = try QuickAddTests.learner()

        let outcome = try learner.tutor.addMyWord(NewMyWord(text: "sluggishly", translation: "медленно", example: nil))
        let card = try learner.nextCard()

        #expect(outcome == .added(headword: "sluggishly"))
        #expect(card.prompt == "sluggishly")
        #expect(card.kind == .mine)
        #expect(card.correctAnswer == "медленно")
        #expect(card.example == nil)
    }

    @Test("each candidate has its own standing, and a word in learning is not added again")
    func standingPerCandidate() throws {
        let learner = try QuickAddTests.learner()
        _ = try learner.tutor.addMyWord(NewMyWord(text: "rapid", translation: "быстрый", example: nil))
        try learner.answerNext()
        _ = try learner.tutor.addMyWord(NewMyWord(text: "swift", translation: "быстрый", example: nil))

        let preview = try #require(try learner.tutor.quickAddPreview("быстрый"))
        let outcome = try learner.tutor.addMyWord(NewMyWord(text: "rapid", translation: "быстрый", example: nil))

        #expect(preview.candidates.map(\.standing) == [.learning(mastery: 1), .notAdded, .mine, .notAdded, .notAdded])
        #expect(preview.candidates.map(\.canAdd) == [false, true, false, true, true])
        #expect(outcome == .alreadyAdded(.learning(mastery: 1)))
    }

    @Test("a word added from Russian input asks the English word with the typed Russian word as the answer")
    func addedFromRussianBecomesCard() throws {
        let learner = try QuickAddTests.learner()
        let preview = try #require(try learner.tutor.quickAddPreview("сомнение"))
        let chosen = try #require(preview.candidates.last)

        let outcome = try learner.tutor.addMyWord(NewMyWord(
            text: chosen.headword,
            translation: try #require(preview.russianText),
            example: nil
        ))
        let card = try learner.nextCard()

        #expect(outcome == .added(headword: "hesitation"))
        #expect(card.headword == "hesitation")
        #expect(card.prompt == "hesitation")
        #expect(card.kind == .mine)
        #expect(card.correctAnswer == "сомнение")
        #expect(!card.options.contains("колебание"))
    }
}
