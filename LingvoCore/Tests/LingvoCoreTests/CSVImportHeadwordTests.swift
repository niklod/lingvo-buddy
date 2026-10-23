import Foundation
import LingvoCore
import Testing

/// Spreadsheets often change the case of the first cell; import follows the quick-add case rules.
@Suite("CSV import headword case")
struct CSVImportHeadwordTests {
    @Test("an import line in another case replaces my word instead of adding a second one")
    func importMatchesMyWordIgnoringCase() throws {
        let learner = try QuickAddTests.learner()
        _ = try learner.tutor.addMyWord(NewMyWord(text: "Kubernetes", translation: "кубернетес", example: nil))

        try learner.tutor.importCSV(Data("headword,translation\nkubernetes,к8с\n".utf8))
        let rows = try learner.tutor.wordList(.myWords).rows

        #expect(rows.map(\.headword) == ["kubernetes"])
        #expect(rows.first?.translation == "к8с")
    }

    @Test("a dictionary word typed with a capital letter imports onto the dictionary word")
    func importMatchesDictionaryWordIgnoringCase() throws {
        let learner = try QuickAddTests.learner()

        try learner.tutor.importCSV(Data("headword,status,mastery\nThey,learned,4\n".utf8))

        #expect(try learner.tutor.quickAddPreview("they")?.standing == .learned)
        #expect(try learner.tutor.wordList(.learned).rows.map(\.headword) == ["they"])
    }

    @Test("an own translation typed with a capital letter lands on the dictionary word")
    func ownTranslationMatchesDictionaryWordIgnoringCase() throws {
        let learner = try QuickAddTests.learner()

        try learner.tutor.importCSV(Data("headword,own_translation\nYear,годик\n".utf8))

        #expect(try learner.tutor.wordList(.queue).rows.first { $0.headword == "year" }?.translation == "годик")
    }

    @Test("an own translation of a word the dictionary lacks is refused")
    func ownTranslationOfUnknownWordIsRefused() throws {
        let learner = try QuickAddTests.learner()

        #expect(throws: CSVImportError.unknownWord(line: 2, headword: "zzzz")) {
            try learner.tutor.importCSV(Data("headword,own_translation\nzzzz,что-то\n".utf8))
        }
    }
}
