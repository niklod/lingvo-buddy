import Foundation
import LingvoCore
import Testing

/// Every saved translation looks like a dictionary one: a single lower-case variant (spec #46).
@Suite("Translation shape on save")
struct TranslationShapeTests {
    private func learner() throws -> Learner {
        try Learner(settings: LearningSettings(direction: .enToRu))
    }

    private func addAndReadCard(_ text: String, translation: String) throws -> Card {
        let learner = try learner()
        _ = try learner.tutor.addMyWord(NewMyWord(text: text, translation: translation, example: nil))
        return try learner.nextCard()
    }

    @Test("a machine-style translation with two variants saves its first variant in lower case")
    func firstVariantLowerCased() throws {
        let card = try addAndReadCard("skedaddle", translation: "Сматываться, смотаться")

        #expect(card.headword == "skedaddle")
        #expect(card.correctAnswer == "сматываться")
    }

    @Test("an abbreviation keeps its capitals and a name loses its capital")
    func abbreviationKept() throws {
        #expect(try addAndReadCard("usa", translation: "США").correctAnswer == "США")
        #expect(try addAndReadCard("un", translation: "ООН").correctAnswer == "ООН")
        #expect(try addAndReadCard("moscow", translation: "Москва").correctAnswer == "москва")
    }

    @Test("every separator ends the first variant")
    func separators() throws {
        #expect(try addAndReadCard("flee", translation: "Смыться; удрать").correctAnswer == "смыться")
        #expect(try addAndReadCard("flee", translation: "Смыться/удрать").correctAnswer == "смыться")
        #expect(try addAndReadCard("flee", translation: " , Смыться, удрать").correctAnswer == "смыться")
    }

    @Test("a translation of separators only is a missing translation")
    func onlySeparators() throws {
        let learner = try learner()

        #expect(throws: LingvoCoreError.missingTranslation("flee")) {
            try learner.tutor.addMyWord(NewMyWord(text: "flee", translation: " , ; ", example: nil))
        }
    }

    @Test("a word no dictionary knows gets a lower-case headword, and an abbreviation keeps its capitals")
    func unknownHeadwordCase() throws {
        let learner = try learner()

        let skedaddle = try learner.tutor.addMyWord(NewMyWord(text: "Skedaddle", translation: "смыться", example: nil))
        let api = try learner.tutor.addMyWord(NewMyWord(text: "API", translation: "интерфейс", example: nil))

        #expect(skedaddle == .added(headword: "skedaddle"))
        #expect(api == .added(headword: "API"))
        #expect(try learner.tutor.wordList(.myWords).rows.map(\.headword).sorted() == ["API", "skedaddle"])
    }

    @Test("the same word typed in another case is already added")
    func unknownHeadwordDuplicate() throws {
        let learner = try learner()
        _ = try learner.tutor.addMyWord(NewMyWord(text: "Skedaddle", translation: "смыться", example: nil))

        let outcome = try learner.tutor.addMyWord(NewMyWord(text: "skedaddle", translation: "удрать", example: nil))

        #expect(outcome == .alreadyAdded(.mine))
    }

    @Test("a translation edit with a separator is refused and nothing changes")
    func editRefusesSeparator() throws {
        let learner = try learner()
        _ = try learner.tutor.addMyWord(NewMyWord(text: "skedaddle", translation: "смыться", example: nil))

        #expect(throws: LingvoCoreError.severalTranslations) {
            try learner.tutor.editTranslation("skedaddle", to: "a, b")
        }
        #expect(LingvoCoreError.severalTranslations.errorDescription == "One translation per card.")
        #expect(try learner.nextCard().correctAnswer == "смыться")
    }

    @Test("an edited translation of a my word is saved in lower case")
    func editLowerCasesMyWord() throws {
        let learner = try learner()
        _ = try learner.tutor.addMyWord(NewMyWord(text: "skedaddle", translation: "смыться", example: nil))

        try learner.tutor.editTranslation("skedaddle", to: " Слово ")

        #expect(try learner.nextCard().correctAnswer == "слово")
    }

    @Test("an edited translation of a dictionary word is saved in lower case, an abbreviation as typed")
    func editLowerCasesDictionaryWord() throws {
        let learner = try learner()

        try learner.tutor.editTranslation("they", to: "Слово")
        #expect(try learner.tutor.wordList(.queue).rows.first { $0.headword == "they" }?.translation == "слово")

        try learner.tutor.editTranslation("they", to: "ООН")
        #expect(try learner.tutor.wordList(.queue).rows.first { $0.headword == "they" }?.translation == "ООН")
    }

    @Test("CSV import keeps the first variant of a my word translation and does not refuse the row")
    func importMyWordTranslation() throws {
        let learner = try learner()

        let summary = try learner.tutor.importCSV(Data("headword,translation\nFlee,Смыться; удрать\n".utf8))
        let row = try #require(try learner.tutor.wordList(.myWords).rows.first)

        #expect(summary == CSVImportSummary(words: 1, myWords: 1))
        #expect(row.headword == "flee")
        #expect(row.translation == "смыться")
    }

    @Test("CSV import shapes an own translation of a dictionary word")
    func importOwnTranslation() throws {
        let learner = try learner()

        try learner.tutor.importCSV(Data("headword,own_translation\nthey,\"Они, сами\"\n".utf8))

        #expect(try learner.tutor.wordList(.queue).rows.first { $0.headword == "they" }?.translation == "они")
    }
}
