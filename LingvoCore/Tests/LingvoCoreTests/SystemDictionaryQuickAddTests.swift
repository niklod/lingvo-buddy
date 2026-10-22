import LingvoCore
import Testing

@Suite("Quick add with the system dictionary")
struct SystemDictionaryQuickAddTests {
    static let all = FakeSystemDictionary(definitions: [
        "mumpsimus": SystemSamples.mumpsimus,
        "skedaddle": SystemSamples.skedaddle,
        "petrichor": SystemSamples.petrichor,
        "persnickety": SystemSamples.persnickety,
        "codswallop": SystemSamples.codswallop,
        "run": SystemSamples.run,
        "colour": SystemSamples.unicolor,
        "garbage": SystemSamples.garbage,
        // The bundled sample dictionary has this word: the system text must change nothing.
        "provide": SystemSamples.skedaddle.replacingOccurrences(of: "skedaddle", with: "provide"),
    ])

    static func tutor(
        system: (any SystemDictionary)? = all, extended: [ExtendedEntry]? = nil
    ) throws -> Tutor {
        try Fixture.tutor(
            extendedDictionary: extended.map { try ExtendedDictionary.inMemory(english: $0) },
            systemDictionary: system
        )
    }

    private func candidate(_ word: String, in tutor: Tutor) throws -> QuickAddCandidate {
        try #require(try tutor.quickAddPreview(word)).candidates[0]
    }

    @Test("a word only the system dictionary has shows IPA, part of speech, example and the definition hint")
    func systemOnly() throws {
        let candidate = try candidate("skedaddle", in: try Self.tutor())

        #expect(candidate.ipa == "/skəˈdædəl/")
        #expect(candidate.partOfSpeech == .verb)
        #expect(candidate.example == "when he saw us, he skedaddled.")
        #expect(candidate.russianExample == nil)
        #expect(candidate.definitionHint == "depart quickly or hurriedly; run away")
        #expect(candidate.translations.isEmpty)
    }

    @Test("a definition without an example gives no example")
    func noExample() throws {
        let candidate = try candidate("mumpsimus", in: try Self.tutor())

        #expect(candidate.ipa == "/ˈmʌmpsəməs/")
        #expect(candidate.partOfSpeech == .noun)
        #expect(candidate.example == nil)
        #expect(candidate.definitionHint == "a traditional custom or notion adhered to although shown to be unreasonable")
    }

    @Test("region and register labels do not start the hint")
    func labelsAreSkipped() throws {
        let tutor = try Self.tutor()

        let persnickety = try candidate("persnickety", in: tutor)
        let codswallop = try candidate("codswallop", in: tutor)

        #expect(persnickety.definitionHint == "placing too much emphasis on trivial or minor details; fussy")
        #expect(persnickety.example == "she's very persnickety about her food.")
        #expect(persnickety.ipa == "/pɚˈsnɪkədi/")
        #expect(codswallop.definitionHint == "nonsense")
        #expect(codswallop.ipa == "/ˈkɑdzˌwɑləp/")
    }

    @Test("a bracketed grammar note before the first sense does not start the hint")
    func bracketedNotesAreSkipped() throws {
        let candidate = try candidate("run", in: try Self.tutor())

        #expect(candidate.ipa == "/rʌn/")
        #expect(candidate.partOfSpeech == .verb)
        #expect(candidate.definitionHint == "move at a speed faster than a walk, never having both or all the feet on the ground at the same time")
        #expect(candidate.example == "the dog ran across the road")
    }

    @Test("text that is not an entry for the word gives nothing, not an error")
    func unparsableText() throws {
        let tutor = try Self.tutor()

        let garbage = try candidate("garbage", in: tutor)
        let mismatch = try candidate("colour", in: tutor)

        for candidate in [garbage, mismatch] {
            #expect(candidate.ipa == nil)
            #expect(candidate.partOfSpeech == nil)
            #expect(candidate.example == nil)
            #expect(candidate.definitionHint == nil)
        }
    }

    @Test("a word the system dictionary lacks shows nothing from it")
    func unknownToSystem() throws {
        let candidate = try candidate("Kubernetes", in: try Self.tutor())

        #expect(candidate.ipa == nil)
        #expect(candidate.partOfSpeech == nil)
        #expect(candidate.definitionHint == nil)
    }

    @Test("extended data wins per field; the system dictionary fills what is missing")
    func extendedWinsPerField() throws {
        let extended = ExtendedEntry(
            headword: "petrichor",
            partOfSpeech: .adjective,
            ipa: nil,
            translations: ["петрихор"],
            example: nil,
            russianExample: nil
        )
        let candidate = try candidate("petrichor", in: try Self.tutor(extended: [extended]))

        #expect(candidate.ipa == "/ˈpɛtraɪˌkɔr/")
        #expect(candidate.partOfSpeech == .adjective)
        #expect(candidate.example?.hasPrefix("other than the petrichor emanating") == true)
        #expect(candidate.definitionHint?.hasPrefix("a pleasant smell that frequently accompanies the first rain") == true)
        #expect(candidate.translations == ["петрихор"])
    }

    @Test("extended IPA and example beat the system ones")
    func extendedFieldsWin() throws {
        let extended = ExtendedEntry(
            headword: "skedaddle",
            partOfSpeech: .noun,
            ipa: "/extended/",
            translations: ["удирать"],
            example: "He will skedaddle.",
            russianExample: "Он удерёт."
        )
        let candidate = try candidate("skedaddle", in: try Self.tutor(extended: [extended]))

        #expect(candidate.ipa == "/extended/")
        #expect(candidate.partOfSpeech == .noun)
        #expect(candidate.example == "He will skedaddle.")
        #expect(candidate.russianExample == "Он удерёт.")
        #expect(candidate.definitionHint == "depart quickly or hurriedly; run away")
    }

    @Test("a bundled word looks as it did, whatever the system dictionary says")
    func bundledUnchanged() throws {
        let with = try candidate("provide", in: try Self.tutor())
        let without = try candidate("provide", in: try Self.tutor(system: nil))

        #expect(with == without)
        #expect(with.definitionHint == nil)
        #expect(with.example == "The hotel provides free breakfast.")
    }

    @Test("Russian input does not ask the system dictionary for an English entry")
    func russianInputSkipsSystem() throws {
        let russian = FakeSystemDictionary(definitions: ["слово": SystemSamples.skedaddle])
        let candidate = try candidate("слово", in: try Self.tutor(system: russian))

        #expect(candidate.definitionHint == nil)
        #expect(candidate.ipa == nil)
    }

    @Test("adding a word without own text puts the system example on the card")
    func systemExampleGoesOnTheCard() throws {
        let tutor = try Self.tutor()

        _ = try tutor.addMyWord(NewMyWord(text: "skedaddle", translation: "удирать", example: nil))
        let card = try #require(try tutor.nextCard().card)

        #expect(card.headword == "skedaddle")
        #expect(card.example == "when he saw us, he skedaddled.")
    }

    @Test("adding a word saves the system IPA and part of speech, shown on the card and in the Dictionary window")
    func systemDetailsAreSaved() throws {
        let tutor = try Self.tutor()

        _ = try tutor.addMyWord(NewMyWord(text: "skedaddle", translation: "удирать", example: nil))
        let card = try #require(try tutor.nextCard().card)
        let row = try #require(try tutor.wordList(.myWords).rows.first)

        #expect(card.ipa == "/skəˈdædəl/")
        #expect(card.partOfSpeech == .verb)
        #expect(row.ipa == "/skəˈdædəl/")
        #expect(row.partOfSpeech == .verb)
    }

    @Test("adding a word saves extended IPA and part of speech before the system ones")
    func extendedDetailsAreSavedFirst() throws {
        let extended = ExtendedEntry(
            headword: "skedaddle", partOfSpeech: .noun, ipa: "/extended/", translations: ["удирать"]
        )
        let tutor = try Self.tutor(extended: [extended])

        _ = try tutor.addMyWord(NewMyWord(text: "skedaddle", translation: "удирать", example: nil))
        let card = try #require(try tutor.nextCard().card)

        #expect(card.ipa == "/extended/")
        #expect(card.partOfSpeech == .noun)
    }

    @Test("the definition hint is not saved: a word with no example has no card example")
    func hintIsNotSaved() throws {
        let tutor = try Self.tutor()

        _ = try tutor.addMyWord(NewMyWord(text: "mumpsimus", translation: "обычай", example: nil))
        let card = try #require(try tutor.nextCard().card)

        #expect(card.example == nil)
    }
}

@Suite("System dictionary text parsing")
struct SystemEntryTests {
    @Test("the American Oxford notation becomes American IPA", arguments: [
        (SystemSamples.church, "/tʃɝtʃ/"),
        (SystemSamples.rhythm, "/ˈrɪðəm/"),
        (SystemSamples.book, "/bʊk/"),
        (SystemSamples.moon, "/mun/"),
        (SystemSamples.cute, "/kjut/"),
        (SystemSamples.hour, "/ˈaʊɚ/"),
        (SystemSamples.fire, "/ˈfaɪɚ/"),
        (SystemSamples.judge, "/dʒʌdʒ/"),
        (SystemSamples.boy, "/bɔɪ/"),
        (SystemSamples.thing, "/θɪŋ/"),
        (SystemSamples.aunt, "/ænt/"),
        (SystemSamples.sure, "/ʃʊr/"),
        (SystemSamples.yellow, "/ˈjɛloʊ/"),
        (SystemSamples.reluctant, "/rəˈlʌktənt/"),
        (SystemSamples.ephemeral, "/əˈfɛmərəl/"),
    ])
    func ipaTable(text: String, expected: String) throws {
        let word = String(text.prefix { $0 != " " })

        let entry = try #require(SystemEntry.parse(text, for: word))

        #expect(entry.ipa == expected)
    }

    @Test("the example after a bracketed note comes without the note")
    func exampleAfterNote() throws {
        let entry = try #require(SystemEntry.parse(SystemSamples.reluctant, for: "reluctant"))

        #expect(entry.definition == "unwilling and hesitant; disinclined")
        #expect(entry.example == "she seemed reluctant to discuss the matter.")
    }

    @Test("a numbered first sense and a qualifier in parentheses do not start the definition")
    func numberedSense() throws {
        let entry = try #require(SystemEntry.parse(SystemSamples.moon, for: "moon"))

        #expect(entry.definition == "the natural satellite of the earth, visible (chiefly at night) by reflected light from the sun")
        #expect(entry.example == "there was no moon.")
    }

    @Test("the word is matched case-insensitively")
    func caseInsensitive() {
        #expect(SystemEntry.parse(SystemSamples.skedaddle, for: "Skedaddle") != nil)
    }
}
