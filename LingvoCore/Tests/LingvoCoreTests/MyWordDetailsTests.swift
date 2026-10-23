import Foundation
import LingvoCore
import Testing

@Suite("IPA and part of speech of my words")
struct MyWordDetailsTests {
    @Test("a my word added from the extended dictionary shows its IPA and part of speech on the card")
    func cardShowsSavedDetails() throws {
        let learner = try ExtendedQuickAddTests.learner()

        _ = try learner.tutor.addMyWord(NewMyWord(text: "petrichor", translation: "петрихор", example: nil))
        let card = try learner.nextCard()

        #expect(card.ipa == "/ˈpetrɪkɔː/")
        #expect(card.partOfSpeech == .noun)
    }

    @Test("a my word the dictionaries lack has no IPA and keeps the neutral part of speech")
    func unknownWordHasNoDetails() throws {
        let learner = try ExtendedQuickAddTests.learner()

        _ = try learner.tutor.addMyWord(NewMyWord(text: "Kubernetes", translation: "кубернетес", example: nil))
        let card = try learner.nextCard()

        #expect(card.ipa == nil)
        #expect(card.partOfSpeech == .other)
    }

    @Test("the Dictionary window lists the saved IPA and part of speech of a my word")
    func windowRowShowsSavedDetails() throws {
        let learner = try ExtendedQuickAddTests.learner()

        _ = try learner.tutor.addMyWord(NewMyWord(text: "petrichor", translation: "петрихор", example: nil))
        _ = try learner.tutor.addMyWord(NewMyWord(text: "Kubernetes", translation: "кубернетес", example: nil))
        let rows = try learner.tutor.wordList(.myWords).rows
        let petrichor = try #require(rows.first { $0.headword == "petrichor" })
        let kubernetes = try #require(rows.first { $0.headword == "kubernetes" })

        #expect(petrichor == WordRow(
            headword: "petrichor",
            translation: "петрихор",
            mastery: 0,
            lastAnswer: nil,
            source: .mine,
            status: nil,
            ipa: "/ˈpetrɪkɔː/",
            partOfSpeech: .noun
        ))
        #expect(kubernetes == WordRow(
            headword: "kubernetes", translation: "кубернетес", mastery: 0, lastAnswer: nil, source: .mine, status: nil
        ))
    }

    @Test("the IPA and part of speech of my words survive a CSV export and import")
    func csvRoundTrip() throws {
        let source = try ExtendedQuickAddTests.learner()
        _ = try source.tutor.addMyWord(NewMyWord(text: "petrichor", translation: "петрихор", example: nil))
        source.clock.advance(by: Fixture.minute)
        _ = try source.tutor.addMyWord(NewMyWord(text: "Kubernetes", translation: "кубернетес", example: nil))

        let target = try ExtendedQuickAddTests.learner(extended: nil)
        try target.tutor.importCSV(try source.tutor.exportCSV())
        let rows = try target.tutor.wordList(.myWords).rows
        let card = try target.nextCard()

        #expect(card.headword == "petrichor")
        #expect(card.ipa == "/ˈpetrɪkɔː/")
        #expect(card.partOfSpeech == .noun)
        #expect(rows.first { $0.headword == "petrichor" }?.partOfSpeech == .noun)
        #expect(rows.first { $0.headword == "kubernetes" }?.ipa == nil)
    }

    @Test("a CSV file from before the two columns still imports, with empty IPA and part of speech")
    func olderCSVImports() throws {
        let target = try ExtendedQuickAddTests.learner()
        let csv = "headword,translation,example,added_at\npetrichor,петрихор,,2026-10-15T09:30:00.000Z\n"

        try target.tutor.importCSV(Data(csv.utf8))
        let card = try target.nextCard()

        #expect(card.correctAnswer == "петрихор")
        #expect(card.ipa == nil)
        #expect(card.partOfSpeech == .other)
    }

    @Test("an unknown part of speech in a CSV file is refused and names the column")
    func unknownPartOfSpeechInCSV() throws {
        let target = try ExtendedQuickAddTests.learner()
        let csv = "headword,translation,pos\npetrichor,петрихор,gizmo\n"

        #expect(throws: CSVImportError.invalidValue(
            line: 2, column: "pos", value: "gizmo", expected: PartOfSpeech.allCases.map(\.rawValue).joined(separator: ", ")
        )) { try target.tutor.importCSV(Data(csv.utf8)) }
    }
}
