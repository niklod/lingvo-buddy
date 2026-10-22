import Foundation
import LingvoCore
import Testing

@Suite("Quick add from Russian with the extended dictionary")
struct ExtendedRussianQuickAddTests {
    static let english = [ExtendedQuickAddTests.petrichor, ExtendedQuickAddTests.skedaddle]
    static let russian = [
        ExtendedRussianEntry(word: "петрихор", translations: ["petrichor"]),
        ExtendedRussianEntry(
            word: "удирать",
            translations: ["skedaddle", "scram", "bolt", "hightail", "decamp", "abscond"]
        ),
        // "provide" is a bundled headword: the bundled data must win for that candidate.
        ExtendedRussianEntry(word: "снабдить", translations: ["provide", "furnish"]),
        // «предлагать» has bundled candidates, so this entry must stay unused.
        ExtendedRussianEntry(word: "предлагать", translations: ["tender"]),
    ]

    static func learner() throws -> Learner {
        let dictionary = try ExtendedDictionary.inMemory(english: english, russian: russian)
        let clock = TestClock(Fixture.start)
        let tutor = try Fixture.tutor(
            clock: clock, settings: LearningSettings(direction: .enToRu), extendedDictionary: dictionary
        )
        return Learner(tutor: tutor, clock: clock)
    }

    @Test("an unknown Russian word lists the English words of the extended dictionary, the first preselected")
    func candidatesFromExtended() throws {
        let learner = try Self.learner()

        let preview = try #require(try learner.tutor.quickAddPreview(" Удирать "))

        // The typed word, as typed, becomes the card's translation.
        #expect(preview == QuickAddPreview(russianText: "Удирать", candidates: [
            QuickAddCandidate(
                headword: "skedaddle", lookup: nil, standing: .notAdded, extended: ExtendedQuickAddTests.skedaddle
            ),
            QuickAddCandidate(headword: "scram", lookup: nil, standing: .notAdded),
            QuickAddCandidate(headword: "bolt", lookup: nil, standing: .notAdded),
            QuickAddCandidate(headword: "hightail", lookup: nil, standing: .notAdded),
            QuickAddCandidate(headword: "decamp", lookup: nil, standing: .notAdded),
        ]))
    }

    @Test("an English candidate shows the extended details the data has for it")
    func candidateDetails() throws {
        let learner = try Self.learner()

        let preview = try #require(try learner.tutor.quickAddPreview("петрихор"))

        #expect(preview.candidates[0].extended == ExtendedQuickAddTests.petrichor)
        #expect(preview.example == "The petrichor rose after the storm.")
        #expect(preview.russianExample == "Запах земли поднялся после грозы.")
        let plain = try #require(try learner.tutor.quickAddPreview("удирать")).candidates[1]
        #expect(plain.headword == "scram")
        #expect(plain.extended == nil)
        #expect(plain.example == nil)
    }

    @Test("a bundled English headword among the candidates keeps its bundled data")
    func bundledCandidateWins() throws {
        let learner = try Self.learner()

        let preview = try #require(try learner.tutor.quickAddPreview("снабдить"))

        #expect(preview.candidates.map(\.headword) == ["provide", "furnish"])
        #expect(preview.candidates[0].lookup != nil)
        #expect(preview.candidates[1].lookup == nil)
        #expect(preview.example == "The hotel provides free breakfast.")
    }

    @Test("bundled Russian candidates win over the extended ones")
    func bundledRussianWins() throws {
        let learner = try Self.learner()

        let preview = try #require(try learner.tutor.quickAddPreview("предлагать"))

        #expect(preview.candidates.map(\.headword) == ["offer", "suggest", "propose"])
    }

    @Test("Russian text with no data anywhere takes the path of an unknown word")
    func noDataAnywhere() throws {
        let learner = try Self.learner()

        let preview = try #require(try learner.tutor.quickAddPreview("медленно"))

        #expect(preview.russianText == nil)
        #expect(preview.isRussianInput)
        #expect(preview.headword == "медленно")
        #expect(preview.canAdd)
    }

    @Test("adding a chosen English candidate saves the typed Russian word as the translation")
    func addChosenCandidate() throws {
        let learner = try Self.learner()
        let preview = try #require(try learner.tutor.quickAddPreview("удирать"))
        let chosen = preview.candidates[1]

        let outcome = try learner.tutor.addMyWord(NewMyWord(
            text: chosen.headword, translation: try #require(preview.russianText), example: nil
        ))
        let card = try learner.nextCard()

        #expect(outcome == .added(headword: "scram"))
        #expect(card.headword == "scram")
        #expect(card.kind == .mine)
        #expect(card.correctAnswer == "удирать")
    }

    @Test("the chosen English word with extended data puts its example on the card")
    func addCandidateWithExample() throws {
        let learner = try Self.learner()
        let preview = try #require(try learner.tutor.quickAddPreview("петрихор"))

        _ = try learner.tutor.addMyWord(NewMyWord(
            text: preview.headword, translation: try #require(preview.russianText), example: nil
        ))
        let card = try learner.nextCard()

        #expect(card.headword == "petrichor")
        #expect(card.correctAnswer == "петрихор")
        #expect(card.example == "The petrichor rose after the storm.")
    }
}
