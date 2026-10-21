import Foundation
import LingvoCore
import Testing

@Suite("Bundled dictionary contract")
struct DictionaryContractTests {
    @Test("a built dictionary file opens read-only and keeps entries, translation order and meta")
    func builtFileRoundTrips() throws {
        let url = Fixture.temporaryDatabaseURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let source = try DictionarySource.decode(json: Fixture.sampleDictionaryData())

        try DictionaryBuilder.buildFile(from: source, at: url)
        let store = try DictionaryStore.open(at: url)

        let entry = try #require(try store.entry(headword: "reluctant"))
        #expect(entry.rank == 4870)
        #expect(entry.partOfSpeech == .adjective)
        #expect(entry.ipa == "/rɪˈlʌktənt/")
        #expect(entry.tier == .lookup)
        #expect(entry.translations[.russian] == ["неохотный", "нежелающий", "сопротивляющийся"])
        #expect(try store.meta()["built_from"] == "sample-dictionary.json")
    }

    @Test("a tutor runs on a dictionary file built from the sample")
    func tutorRunsOnBuiltFile() throws {
        let url = Fixture.temporaryDatabaseURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try DictionaryBuilder.buildFile(from: DictionarySource.decode(json: Fixture.sampleDictionaryData()), at: url)
        let tutor = try Tutor(
            dictionary: try DictionaryStore.open(at: url),
            userDatabase: try UserDatabase.inMemory(),
            clock: TestClock(Fixture.start),
            random: SeededRandomSource(seed: 7)
        )

        let card = try #require(try tutor.nextCard().card)

        #expect(card.headword == "they")
    }

    @Test("a duplicate headword is rejected")
    func duplicateHeadwordIsRejected() throws {
        let json = Data("""
        {"entries": [
          {"headword": "go", "rank": 1, "pos": "verb", "ipa": null, "example": null, "synonym_group": null,
           "tier": "lookup", "translations": {"ru": ["идти"]}},
          {"headword": "go", "rank": 2, "pos": "verb", "ipa": null, "example": null, "synonym_group": null,
           "tier": "lookup", "translations": {"ru": ["ехать"]}}
        ]}
        """.utf8)

        #expect(throws: LingvoCoreError.self) {
            try DictionaryStore.inMemory(fromJSON: [json])
        }
    }

    @Test("a quiz exclusion of a word that is not in the dictionary is rejected")
    func unknownQuizExclusionIsRejected() throws {
        let json = Data("""
        {"entries": [{"headword": "go", "rank": 1, "pos": "verb", "ipa": null, "example": null,
          "synonym_group": null, "tier": "lookup", "translations": {"ru": ["идти"]}}],
         "quiz_exclusions": ["dude"]}
        """.utf8)

        #expect(throws: LingvoCoreError.self) {
            try DictionaryStore.inMemory(fromJSON: [json])
        }
    }

    @Test("an unknown part of speech is rejected")
    func unknownPartOfSpeechIsRejected() throws {
        let json = Data("""
        {"entries": [{"headword": "go", "rank": 1, "pos": "gerund", "ipa": null, "example": null,
          "synonym_group": null, "tier": "lookup", "translations": {"ru": ["идти"]}}]}
        """.utf8)

        #expect(throws: LingvoCoreError.invalidDictionary("go: unknown part of speech \"gerund\"")) {
            try DictionarySource.decode(json: json)
        }
    }

    @Test("opening a missing dictionary file fails with a clear error")
    func missingFileFails() throws {
        #expect(throws: LingvoCoreError.self) {
            try DictionaryStore.open(at: Fixture.temporaryDatabaseURL())
        }
    }
}
