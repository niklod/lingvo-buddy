import Foundation
import LingvoCore
import Testing

@Suite("Quick add with the extended dictionary")
struct ExtendedQuickAddTests {
    static let petrichor = ExtendedEntry(
        headword: "petrichor",
        partOfSpeech: .noun,
        ipa: "/ˈpetrɪkɔː/",
        translations: ["петрихор", "запах дождя"],
        example: "The petrichor rose after the storm.",
        russianExample: "Запах земли поднялся после грозы."
    )
    static let skedaddle = ExtendedEntry(
        headword: "skedaddle", partOfSpeech: .verb, translations: ["улепётывать", "удирать"]
    )
    /// "provide" is in the bundled sample dictionary too: the bundled data must win.
    static let provide = ExtendedEntry(
        headword: "provide",
        partOfSpeech: .noun,
        ipa: "/extended/",
        translations: ["extended translation"],
        example: "An extended example."
    )

    static func learner(extended: [ExtendedEntry]? = [petrichor, skedaddle, provide]) throws -> Learner {
        let dictionary = try extended.map { try ExtendedDictionary.inMemory(english: $0) }
        let clock = TestClock(Fixture.start)
        let tutor = try Fixture.tutor(
            clock: clock, settings: LearningSettings(direction: .enToRu), extendedDictionary: dictionary
        )
        return Learner(tutor: tutor, clock: clock)
    }

    @Test("a word outside the bundled dictionary shows the extended translations, IPA, part of speech and examples")
    func previewShowsExtendedDetails() throws {
        let learner = try Self.learner()

        let preview = try #require(try learner.tutor.quickAddPreview("  Petrichor "))

        #expect(preview == QuickAddPreview(
            headword: "petrichor", lookup: nil, standing: .notAdded, extended: Self.petrichor
        ))
    }

    @Test("an extended word without IPA or example shows only what it has")
    func previewWithoutOptionalFields() throws {
        let learner = try Self.learner()

        let preview = try #require(try learner.tutor.quickAddPreview("skedaddle"))

        #expect(preview.candidates[0].translations == ["улепётывать", "удирать"])
        #expect(preview.candidates[0].extended?.ipa == nil)
        #expect(preview.example == nil)
        #expect(preview.russianExample == nil)
    }

    @Test("the bundled dictionary wins over the extended one")
    func bundledWins() throws {
        let learner = try Self.learner()

        let preview = try #require(try learner.tutor.quickAddPreview("provide"))

        #expect(preview.lookup != nil)
        #expect(preview.candidates[0].extended == nil)
        #expect(preview.candidates[0].translations == ["обеспечивать", "предоставлять"])
        #expect(preview.example == "The hotel provides free breakfast.")
    }

    @Test("a word in neither dictionary has no translation to show, so the machine translation can fill in")
    func unknownWord() throws {
        let learner = try Self.learner()

        let preview = try #require(try learner.tutor.quickAddPreview("Kubernetes"))

        #expect(preview.headword == "Kubernetes")
        #expect(preview.candidates[0].extended == nil)
        #expect(preview.candidates[0].translations.isEmpty)
    }

    @Test("without an extended dictionary a word outside the bundled one looks as it did before")
    func noExtendedDictionary() throws {
        let learner = try Self.learner(extended: nil)

        let preview = try #require(try learner.tutor.quickAddPreview("Petrichor"))

        #expect(preview.headword == "Petrichor")
        #expect(preview.candidates[0].extended == nil)
        #expect(preview.candidates[0].translations.isEmpty)
        #expect(preview.example == nil)
    }

    @Test("adding a word with an extended bubble saves that translation and the extended example for the card")
    func addWithExtendedBubble() throws {
        let learner = try Self.learner()

        let outcome = try learner.tutor.addMyWord(NewMyWord(text: "petrichor", translation: "запах дождя", example: " "))
        let card = try learner.nextCard()

        #expect(outcome == .added(headword: "petrichor"))
        #expect(card.headword == "petrichor")
        #expect(card.kind == .mine)
        #expect(card.correctAnswer == "запах дождя")
        #expect(card.example == "The petrichor rose after the storm.")
    }

    @Test("own \"Where I saw it\" text replaces the extended example")
    func ownExampleWins() throws {
        let learner = try Self.learner()

        _ = try learner.tutor.addMyWord(NewMyWord(text: "petrichor", translation: "петрихор", example: "I love petrichor."))
        let card = try learner.nextCard()

        #expect(card.example == "I love petrichor.")
    }

    @Test("an extended word without an example puts none on the card")
    func noExampleToSave() throws {
        let learner = try Self.learner()

        _ = try learner.tutor.addMyWord(NewMyWord(text: "skedaddle", translation: "удирать", example: nil))
        let card = try learner.nextCard()

        #expect(card.example == nil)
    }

    @Test("a word already added is found again under the headword the learner saved")
    func alreadyAdded() throws {
        let learner = try Self.learner()
        _ = try learner.tutor.addMyWord(NewMyWord(text: "petrichor", translation: "петрихор", example: nil))

        let preview = try #require(try learner.tutor.quickAddPreview("PETRICHOR"))

        #expect(preview.headword == "petrichor")
        #expect(preview.standing == .mine)
        #expect(!preview.canAdd)
    }
}
