import Foundation
import LingvoCore
import Testing

@Suite("CSV import of invalid files")
struct CSVImportErrorTests {
    struct BadFile: Sendable, CustomTestStringConvertible {
        let name: String
        let data: Data
        let error: CSVImportError

        init(_ name: String, _ text: String, _ error: CSVImportError) {
            self.init(name, data: Data(text.utf8), error)
        }

        init(_ name: String, data: Data, _ error: CSVImportError) {
            self.name = name
            self.data = data
            self.error = error
        }

        var testDescription: String { name }
    }

    /// Line 2 is always valid, so a failing import must also undo it.
    static let header = "headword,translation,status,mastery,due_at\n"
    static let validLine = "eventually,со временем,,,\n"

    static let badFiles: [BadFile] = [
        BadFile("empty file", "", .empty),
        BadFile("not UTF-8", data: Data([0xFF, 0xFE, 0x41, 0x00, 0xE9]), .notUTF8),
        BadFile("another app's CSV", "name,age\nBob,4\n", .unknownColumns(["name", "age"])),
        BadFile("no headword column", "translation\nсо временем\n", .missingColumns(["headword"])),
        BadFile("a column twice", "headword,status,status\nx,learning,learning\n", .duplicateColumns(["status"])),
        BadFile(
            "unknown status",
            header + validLine + "reluctant,,maybe,1,\n",
            .invalidValue(line: 3, column: "status", value: "maybe", expected: "learning, learned")
        ),
        BadFile(
            "mastery out of range",
            header + validLine + "reluctant,,learning,7,\n",
            .invalidValue(line: 3, column: "mastery", value: "7", expected: "a whole number from 0 to 4")
        ),
        BadFile(
            "broken due time",
            header + validLine + "reluctant,,learning,1,tomorrow\n",
            .invalidValue(line: 3, column: "due_at", value: "tomorrow", expected: "a time like 2026-10-15T09:30:00.000Z")
        ),
        BadFile(
            "a date that does not exist",
            header + validLine + "reluctant,,learning,1,2026-02-30T10:00:00Z\n",
            .invalidValue(
                line: 3, column: "due_at", value: "2026-02-30T10:00:00Z", expected: "a time like 2026-10-15T09:30:00.000Z"
            )
        ),
        BadFile("quote never closed", header + validLine + "reluctant,\"неохотный,,,\n", .unterminatedQuote(line: 3)),
        BadFile("quote inside a plain value", header + validLine + "relu\"ctant,x,,,\n", .misplacedQuote(line: 3)),
        BadFile(
            "too many values",
            header + validLine + "reluctant,x,learning,1,,extra\n",
            .wrongFieldCount(line: 3, expected: 5, found: 6)
        ),
        BadFile("empty headword", header + validLine + " ,x,,,\n", .missingValue(line: 3, column: "headword")),
        BadFile(
            "the same word twice",
            header + validLine + "eventually,в итоге,,,\n",
            .duplicateWord(line: 3, headword: "eventually")
        ),
        BadFile(
            "the same word twice in another case",
            header + validLine + "Eventually,в итоге,,,\n",
            .duplicateWord(line: 3, headword: "Eventually")
        ),
        BadFile(
            "progress for a word that is neither in the dictionary nor a my word",
            header + validLine + "zzzz,,learning,2,\n",
            .unknownWord(line: 3, headword: "zzzz")
        ),
        BadFile(
            "progress without a status",
            header + validLine + "reluctant,,,2,\n",
            .progressWithoutStatus(line: 3, column: "mastery")
        ),
        BadFile("a line with nothing to import", header + validLine + "reluctant,,,,\n", .nothingToImport(line: 3, headword: "reluctant")),
        BadFile(
            "translation too long",
            header + validLine + "reluctant,\(String(repeating: "я", count: NewMyWord.maxTranslationLength + 1)),,,\n",
            .tooLong(line: 3, column: "translation", limit: NewMyWord.maxTranslationLength)
        ),
    ]

    @Test("an invalid file is rejected with a clear error and changes nothing", arguments: badFiles)
    func invalidFileChangesNothing(_ file: BadFile) throws {
        let learner = try QuickAddTests.learner()
        try learner.answerNext()
        _ = try learner.tutor.addMyWord(NewMyWord(text: "reluctant", translation: "неохотный", example: nil))
        let before = try learner.tutor.exportCSV()

        #expect(throws: file.error) { try learner.tutor.importCSV(file.data) }
        #expect(try learner.tutor.exportCSV() == before)
        #expect(try learner.tutor.stats().myWordsCount == 1)
    }

    @Test("the error message names the line, the column and what was expected")
    func errorMessageIsClear() {
        let error = CSVImportError.invalidValue(line: 3, column: "status", value: "maybe", expected: "learning, learned")

        #expect(error.localizedDescription == "Line 3: \"maybe\" is not a valid status. Expected: learning, learned.")
    }

    @Test("a file larger than any real export is rejected before it is read")
    func oversizedFile() throws {
        let learner = try QuickAddTests.learner()
        let huge = Data(count: 10_000_001)

        #expect(throws: CSVImportError.fileTooLarge(limitBytes: 10_000_000)) { try learner.tutor.importCSV(huge) }
    }
}
