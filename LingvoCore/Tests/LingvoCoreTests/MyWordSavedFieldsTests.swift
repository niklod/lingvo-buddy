import Foundation
import LingvoCore
import Testing

@Suite("What quick add saves with a my word")
struct MyWordSavedFieldsTests {
    @Test("a word added without own text keeps the extended Russian example on the card")
    func russianExampleGoesOnTheCard() throws {
        let learner = try ExtendedQuickAddTests.learner()

        _ = try learner.tutor.addMyWord(NewMyWord(text: "petrichor", translation: "петрихор", example: nil))
        let card = try learner.nextCard()

        #expect(card.example == "The petrichor rose after the storm.")
        #expect(card.russianExample == "Запах земли поднялся после грозы.")
    }

    @Test("an own example drops the extended Russian example: it translates another sentence")
    func ownExampleHasNoRussianExample() throws {
        let learner = try ExtendedQuickAddTests.learner()

        _ = try learner.tutor.addMyWord(NewMyWord(text: "petrichor", translation: "петрихор", example: "Rain at last."))
        let card = try learner.nextCard()

        #expect(card.example == "Rain at last.")
        #expect(card.russianExample == nil)
    }

    @Test("the Russian example survives a CSV export and import")
    func russianExampleRoundTrip() throws {
        let source = try ExtendedQuickAddTests.learner()
        _ = try source.tutor.addMyWord(NewMyWord(text: "petrichor", translation: "петрихор", example: nil))

        let target = try ExtendedQuickAddTests.learner(extended: nil)
        try target.tutor.importCSV(try source.tutor.exportCSV())
        let card = try target.nextCard()

        #expect(card.russianExample == "Запах земли поднялся после грозы.")
    }

    @Test("a CSV file from before the Russian example column still imports")
    func olderCSVImports() throws {
        let target = try ExtendedQuickAddTests.learner()
        let csv = "headword,translation,example,added_at,ipa,pos\npetrichor,петрихор,,2026-10-15T09:30:00.000Z,,noun\n"

        try target.tutor.importCSV(Data(csv.utf8))
        let card = try target.nextCard()

        #expect(card.correctAnswer == "петрихор")
        #expect(card.russianExample == nil)
    }

    @Test("an IPA longer than a CSV file accepts is not saved, so the backup imports again")
    func overlongIPAIsDropped() throws {
        let longIPA = "/" + String(repeating: "ə", count: NewMyWord.maxIPALength) + "/"
        let extended = ExtendedEntry(headword: "petrichor", partOfSpeech: .noun, ipa: longIPA, translations: ["петрихор"])
        let source = try ExtendedQuickAddTests.learner(extended: [extended])
        _ = try source.tutor.addMyWord(NewMyWord(text: "petrichor", translation: "петрихор", example: nil))

        let target = try ExtendedQuickAddTests.learner(extended: nil)
        try target.tutor.importCSV(try source.tutor.exportCSV())

        #expect(try source.nextCard().ipa == nil)
        #expect(try target.nextCard().ipa == nil)
    }

    @Test("Russian text given as the English word is refused, not swapped for a dictionary word")
    func russianTextIsNotAnEnglishWord() throws {
        let learner = try QuickAddTests.learner()

        #expect(throws: LingvoCoreError.notEnglishWord("сомнение")) {
            try learner.tutor.addMyWord(NewMyWord(text: "сомнение", translation: "сомнение", example: nil))
        }
        #expect(try learner.tutor.stats().myWordsCount == 0)
    }
}
