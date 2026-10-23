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

    @Test("a word with a non-ASCII capital typed again is already added, not a second row")
    func unknownHeadwordNonASCIIDuplicate() throws {
        let learner = try learner()
        _ = try learner.tutor.addMyWord(NewMyWord(text: "Éclair", translation: "эклер", example: nil))
        _ = try learner.tutor.addMyWord(NewMyWord(text: "Kubernetes", translation: "кубернетес", example: nil))

        let eclair = try learner.tutor.addMyWord(NewMyWord(text: "Éclair", translation: "пирожное", example: nil))
        let kubernetes = try learner.tutor.addMyWord(NewMyWord(text: "kubernetes", translation: "к8с", example: nil))

        #expect([eclair, kubernetes] == [.alreadyAdded(.mine), .alreadyAdded(.mine)])
        #expect(try learner.tutor.wordList(.myWords).rows.map(\.headword).sorted() == ["kubernetes", "éclair"])
    }

    @Test("a learner's word given in Russian input saves a lower-case headword and translation")
    func russianInputShape() throws {
        let card = try addAndReadCard("Chatterbox", translation: "Болтушка")

        #expect(card.headword == "chatterbox")
        #expect(card.correctAnswer == "болтушка")
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

    @Test("typing the dictionary translation back in another case leaves no override")
    func editBackToDictionaryTranslation() throws {
        let learner = try learner()

        try learner.tutor.editTranslation("think", to: "полагать")
        try learner.tutor.editTranslation("think", to: "Думать")

        #expect(try ownTranslation(of: "think", in: learner) == "")
    }

    @Test("a translation edit of a dictionary word with a separator is refused")
    func editDictionaryWordRefusesSeparator() throws {
        let learner = try learner()

        #expect(throws: LingvoCoreError.severalTranslations) {
            try learner.tutor.editTranslation("think", to: "a; b")
        }
    }

    @Test("CSV import keeps the first variant of a my word translation and does not refuse the row")
    func importMyWordTranslation() throws {
        let learner = try learner()

        let summary = try learner.tutor.importCSV(Data("headword,translation\nFlee,Смыться; удрать\n".utf8))
        let rows = try learner.tutor.wordList(.myWords).rows

        #expect(summary == CSVImportSummary(words: 1, myWords: 1))
        #expect(rows == [WordRow(headword: "flee", translation: "смыться", mastery: 0, lastAnswer: nil, source: .mine, status: nil)])
    }

    @Test("CSV import shapes an own translation of a dictionary word")
    func importOwnTranslation() throws {
        let learner = try learner()

        try learner.tutor.importCSV(Data("headword,own_translation\nthey,\"Они, сами\"\n".utf8))

        #expect(try learner.tutor.wordList(.queue).rows.first { $0.headword == "they" }?.translation == "они")
    }

    @Test("a CSV cell with separators only is refused with its line and column")
    func importSeparatorsOnly() throws {
        let learner = try learner()

        #expect(throws: CSVImportError.noTranslation(line: 2, column: "translation")) {
            try learner.tutor.importCSV(Data("headword,translation,example\nflee,\",,,\",They fled.\n".utf8))
        }
        #expect(throws: CSVImportError.noTranslation(line: 2, column: "own_translation")) {
            try learner.tutor.importCSV(Data("headword,own_translation\nthey,\" , \"\n".utf8))
        }
    }

    @Test("CSV import keeps an abbreviation headword, and one word in two cases is one word")
    func importHeadwordCase() throws {
        let learner = try learner()

        try learner.tutor.importCSV(Data("headword,translation\nAPI,интерфейс\n".utf8))

        #expect(try learner.tutor.wordList(.myWords).rows.map(\.headword) == ["API"])
        #expect(throws: CSVImportError.duplicateWord(line: 3, headword: "flee")) {
            try learner.tutor.importCSV(Data("headword,translation\nFlee,смыться\nflee,удрать\n".utf8))
        }
    }

    @Test("a cell with several variants longer than a translation imports when its first variant fits")
    func importLongCellWithShortFirstVariant() throws {
        let learner = try learner()
        let long = String(repeating: "о", count: NewMyWord.maxTranslationLength)

        try learner.tutor.importCSV(Data("headword,translation\nflee,\"смыться, \(long)\"\n".utf8))

        #expect(try learner.tutor.wordList(.myWords).rows.map(\.translation) == ["смыться"])
    }

    /// The `own_translation` cell of the word in an export; "" when the word has no row.
    private func ownTranslation(of headword: String, in learner: Learner) throws -> String {
        let csv = try #require(String(bytes: try learner.tutor.exportCSV(), encoding: .utf8))
        let lines = csv.split(whereSeparator: \.isNewline)
        let header = try #require(lines.first).split(separator: ",", omittingEmptySubsequences: false)
        let column = try #require(header.firstIndex(of: "own_translation"))
        guard let line = lines.first(where: { $0.hasPrefix("\(headword),") }) else { return "" }
        return String(line.split(separator: ",", omittingEmptySubsequences: false)[column])
    }
}
