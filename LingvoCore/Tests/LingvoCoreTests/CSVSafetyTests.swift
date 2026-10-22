import Foundation
import LingvoCore
import Testing

@Suite("CSV files from and for other apps")
struct CSVSafetyTests {
    private func learner() throws -> Learner {
        try QuickAddTests.learner()
    }

    @Test("a value that a spreadsheet would run as a formula is exported as text and imported unchanged")
    func formulaLikeValuesRoundTrip() throws {
        let source = try learner()
        let example = "=HYPERLINK(\"http://evil/\",\"click\")"
        _ = try source.tutor.addMyWord(NewMyWord(text: "reluctant", translation: "-ish", example: example))
        source.clock.advance(by: Fixture.minute)
        _ = try source.tutor.addMyWord(NewMyWord(text: "Kubernetes", translation: "@k8s", example: "+1 for it"))

        let exported = try source.tutor.exportCSV()
        let text = try #require(String(data: exported, encoding: .utf8))
        let target = try learner()
        try target.tutor.importCSV(exported)

        #expect(text.contains("'-ish"))
        #expect(text.contains("\"'=HYPERLINK"))
        #expect(text.contains("'@k8s,'+1 for it"))
        #expect(try target.tutor.exportCSV() == exported)
        #expect(try target.nextCard().example == example)
    }

    @Test("a plain apostrophe at the start of a value is kept")
    func leadingApostropheIsKept() throws {
        let target = try learner()

        try target.tutor.importCSV(Data("headword,translation\nKubernetes,'кубер\n".utf8))

        #expect(try target.nextCard().correctAnswer == "'кубер")
    }

    @Test("a file with more lines than any real export is refused")
    func tooManyRows() throws {
        let target = try learner()
        let lines = (0...Tutor.maxCSVImportRows).map { "w\($0),x\n" }.joined()

        #expect(throws: CSVImportError.tooManyRows(limit: 20_000)) {
            try target.tutor.importCSV(Data(("headword,translation\n" + lines).utf8))
        }
        #expect(try target.tutor.stats().myWordsCount == 0)
    }

    @Test("the new error messages say what to do")
    func errorMessages() {
        #expect(CSVImportError.tooManyRows(limit: 20_000).localizedDescription
            == "The file has more than 20000 words. Split it into smaller files.")
        #expect(CSVImportError.semicolonSeparated.localizedDescription
            == "The values are separated by \";\". Save the file as CSV with commas and try again.")
    }
}
