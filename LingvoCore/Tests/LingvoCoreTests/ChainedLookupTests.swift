import LingvoCore
import Testing

@Suite("Details of the English word for a Russian input")
struct ChainedLookupTests {
    static let extended = [
        ExtendedQuickAddTests.petrichor,
        ExtendedEntry(headword: "scram", partOfSpeech: .verb, ipa: "/skræm/", translations: ["убираться"]),
    ]
    static let russian = [
        ExtendedRussianEntry(word: "удирать", translations: ["skedaddle", "scram"]),
    ]
    static let system = FakeSystemDictionary(definitions: [
        "skedaddle": SystemSamples.skedaddle,
        "mumpsimus": SystemSamples.mumpsimus,
        "petrichor": SystemSamples.petrichor,
    ])

    static func tutor() throws -> Tutor {
        try Fixture.tutor(
            extendedDictionary: try ExtendedDictionary.inMemory(english: extended, russian: russian),
            systemDictionary: system
        )
    }

    @Test("an English word the learner picks shows the system details when the extended dictionary has none")
    func systemDetailsForPickedWord() throws {
        let details = try #require(try Self.tutor().englishDetails("skedaddle"))

        #expect(details == QuickAddCandidate(
            headword: "skedaddle", lookup: nil, standing: .notAdded, system: SystemSamples.skedaddleEntry
        ))
    }

    @Test("a typed English word with extended data shows it before the system data, field by field")
    func extendedBeforeSystem() throws {
        let details = try #require(try Self.tutor().englishDetails("  Petrichor "))

        #expect(details == QuickAddCandidate(
            headword: "petrichor",
            lookup: nil,
            standing: .notAdded,
            extended: ExtendedQuickAddTests.petrichor,
            system: SystemSamples.petrichorEntry
        ))
    }

    @Test("a bundled English word keeps its bundled details")
    func bundledWins() throws {
        let details = try #require(try Self.tutor().englishDetails("provide"))

        #expect(details.lookup != nil)
        #expect(details.example == "The hotel provides free breakfast.")
        #expect(details.definitionHint == nil)
    }

    @Test("a word with no data anywhere has details with no fields")
    func nothingKnown() throws {
        let details = try #require(try Self.tutor().englishDetails("kubernetes"))

        #expect(details.ipa == nil)
        #expect(details.translations.isEmpty)
        #expect(details.canAdd)
    }

    @Test("blank text and Russian text have no English details")
    func blankAndRussian() throws {
        let tutor = try Self.tutor()

        #expect(try tutor.englishDetails("   ") == nil)
        #expect(try tutor.englishDetails("удирать") == QuickAddCandidate(headword: "удирать", lookup: nil, standing: .notAdded))
    }

    @Test("a word of My words shows that it is already added")
    func standingIsShown() throws {
        let tutor = try Self.tutor()
        _ = try tutor.addMyWord(NewMyWord(text: "skedaddle", translation: "удирать", example: nil))

        #expect(try tutor.englishDetails("skedaddle")?.standing == .mine)
    }

    @Test("adding the shown English word saves its IPA and part of speech with the typed Russian translation")
    func addSavesShownDetails() throws {
        let tutor = try Self.tutor()
        let preview = try #require(try tutor.quickAddPreview("удирать"))
        let shown = try #require(try tutor.englishDetails(preview.candidates[1].headword))

        _ = try tutor.addMyWord(NewMyWord(text: shown.headword, translation: "удирать", example: nil))
        let card = try #require(try tutor.nextCard().card)

        #expect(card.headword == "scram")
        #expect(card.correctAnswer == "удирать")
        #expect(card.ipa == shown.ipa)
        #expect(card.partOfSpeech == .verb)
    }

    @Test("a custom English word adds with its system IPA, part of speech and example")
    func addCustomEnglishWord() throws {
        let tutor = try Self.tutor()
        let shown = try #require(try tutor.englishDetails("skedaddle"))

        _ = try tutor.addMyWord(NewMyWord(text: "skedaddle", translation: "быстро уйти", example: nil))
        let card = try #require(try tutor.nextCard().card)

        #expect(card.ipa == shown.ipa)
        #expect(card.partOfSpeech == shown.partOfSpeech)
        #expect(card.example == shown.example)
        #expect(card.correctAnswer == "быстро уйти")
    }
}
