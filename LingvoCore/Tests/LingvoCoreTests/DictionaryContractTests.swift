import Foundation
import LingvoCore
import Testing

@Suite("Bundled dictionary contract")
struct DictionaryContractTests {
    private static func entryJSON(_ headword: String, rank: Int, pos: String = "verb", ipa: String = "\"/go/\"") -> String {
        """
        {"headword": "\(headword)", "rank": \(rank), "pos": "\(pos)", "ipa": \(ipa), "example": null,
         "synonym_group": null, "tier": "lookup", "translations": {"ru": ["идти"]}}
        """
    }

    private static func store(_ entries: [String], quizExclusions: [String] = []) throws -> DictionaryStore {
        let exclusions = quizExclusions.map { "\"\($0)\"" }.joined(separator: ", ")
        let json = "{\"entries\": [\(entries.joined(separator: ", "))], \"quiz_exclusions\": [\(exclusions)]}"
        return try DictionaryStore.inMemory(fromJSON: [Data(json.utf8)])
    }

    @Test("a dictionary keeps every source entry with its translation order, and the meta")
    func sourceRoundTrips() throws {
        let source = try DictionarySource.decode(json: Fixture.sampleDictionaryData())

        let store = try DictionaryStore.inMemory(fromJSON: [Fixture.sampleDictionaryData()])

        for expected in source.entries {
            #expect(try store.entry(headword: expected.headword) == expected)
        }
        #expect(try store.meta() == source.meta)
    }

    @Test("the dictionary written for tests has exactly the contract schema")
    func noSchemaDrift() throws {
        #expect(try Fixture.dictionary().schemaDrift() == [])
    }

    @Test("a duplicate headword is rejected")
    func duplicateHeadwordIsRejected() throws {
        #expect(throws: LingvoCoreError.invalidDictionary("UNIQUE constraint failed: entries.headword")) {
            try Self.store([Self.entryJSON("go", rank: 1), Self.entryJSON("go", rank: 2)])
        }
    }

    @Test("an entry without a transcription is rejected, as the Python build rejects it")
    func missingIPAIsRejected() throws {
        #expect(throws: LingvoCoreError.invalidDictionary("NOT NULL constraint failed: entries.ipa")) {
            try Self.store([Self.entryJSON("go", rank: 1, ipa: "null")])
        }
    }

    @Test("a quiz exclusion of a word the source lacks is skipped, as in a partial Python build")
    func unknownQuizExclusionIsSkipped() throws {
        let store = try Self.store([Self.entryJSON("go", rank: 1)], quizExclusions: ["dude"])

        #expect(try store.entry(headword: "go") != nil)
    }

    @Test("an unknown part of speech is rejected")
    func unknownPartOfSpeechIsRejected() throws {
        let json = Data("{\"entries\": [\(Self.entryJSON("go", rank: 1, pos: "gerund"))]}".utf8)

        #expect(throws: LingvoCoreError.invalidDictionary("go: unknown part of speech \"gerund\"")) {
            try DictionarySource.decode(json: json)
        }
    }

    @Test("opening a missing dictionary file fails with a clear error")
    func missingFileFails() throws {
        let url = Fixture.temporaryDatabaseURL()

        #expect(throws: LingvoCoreError.invalidDictionary("no dictionary file at \(url.path)")) {
            try DictionaryStore.open(at: url)
        }
    }
}
