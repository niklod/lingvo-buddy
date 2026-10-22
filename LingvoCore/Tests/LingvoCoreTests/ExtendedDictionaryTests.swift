import Foundation
import LingvoCore
import Testing

@Suite("Extended dictionary file")
struct ExtendedDictionaryTests {
    @Test("the dictionary written for tests has exactly the contract schema, and keeps the licence meta")
    func noSchemaDriftAndMeta() throws {
        let dictionary = try ExtendedDictionary.inMemory(
            english: [ExtendedQuickAddTests.petrichor], meta: ["license": "Wiktionary contributors, CC BY-SA 4.0"]
        )

        #expect(try dictionary.schemaDrift() == [])
        #expect(try dictionary.meta()["license"] == "Wiktionary contributors, CC BY-SA 4.0")
        #expect(try dictionary.counts() == (english: 1, russian: 0))
    }

    @Test("an entry keeps its fields, and a word it lacks is not found")
    func entryRoundTrips() throws {
        let dictionary = try ExtendedDictionary.inMemory(english: [ExtendedQuickAddTests.petrichor])

        #expect(try dictionary.entry(headword: " PETRICHOR ") == ExtendedQuickAddTests.petrichor)
        #expect(try dictionary.entry(headword: "mumpsimus") == nil)
    }

    @Test("a missing file is reported with its path")
    func missingFile() {
        let url = URL(fileURLWithPath: "/nonexistent/extended-dictionary.sqlite")

        #expect(throws: LingvoCoreError.invalidDictionary("no extended dictionary file at \(url.path)")) {
            try ExtendedDictionary.open(at: url)
        }
    }
}
