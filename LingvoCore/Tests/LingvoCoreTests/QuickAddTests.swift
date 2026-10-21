import Foundation
import LingvoCore
import Testing

@Suite("Quick add")
struct QuickAddTests {
    static func learner() throws -> Learner {
        try Learner(settings: LearningSettings(direction: .enToRu))
    }

    @Test("a dictionary word is found ignoring case and spaces, ready to add")
    func previewDictionaryWord() throws {
        let learner = try Learner()

        let preview = try #require(try learner.tutor.quickAddPreview("  Reluctant \n"))

        #expect(preview.headword == "reluctant")
        #expect(preview.lookup?.entry.translations[.russian] == ["неохотный", "нежелающий", "сопротивляющийся"])
        #expect(preview.lookup?.membership == .outside(.top1000))
        #expect(preview.standing == .notAdded)
        #expect(preview.canAdd)
    }

    @Test("a word added with a dictionary translation is the next card, as a My word")
    func addWithDictionaryTranslation() throws {
        let learner = try Self.learner()

        let outcome = try learner.tutor.addMyWord(NewMyWord(text: "Reluctant", translation: "нежелающий", example: nil))
        let card = try learner.nextCard()

        #expect(outcome == .added(headword: "reluctant"))
        #expect(card.headword == "reluctant")
        #expect(card.kind == .mine)
        #expect(card.source == .mine)
        #expect(card.correctAnswer == "нежелающий")
        #expect(card.ipa == "/rɪˈlʌktənt/")
        #expect(card.partOfSpeech == .adjective)
        #expect(!card.options.contains("неохотный"))
    }

    @Test("a custom translation and the \"Where I saw it\" text go on the card")
    func addWithCustomTranslationAndExample() throws {
        let learner = try Self.learner()

        try learner.tutor.addMyWord(NewMyWord(
            text: "eventually",
            translation: " со временем ",
            example: "  It will work eventually. "
        ))
        let card = try learner.nextCard()

        #expect(card.headword == "eventually")
        #expect(card.correctAnswer == "со временем")
        #expect(card.example == "It will work eventually.")
        #expect(!card.options.contains("в конце концов"))
    }

    @Test("a word the dictionary lacks needs a custom translation and then becomes a card")
    func unknownWord() throws {
        let learner = try Self.learner()

        let preview = try #require(try learner.tutor.quickAddPreview(" Kubernetes "))
        #expect(throws: LingvoCoreError.missingTranslation("Kubernetes")) {
            try learner.tutor.addMyWord(NewMyWord(text: "Kubernetes", translation: "  ", example: nil))
        }
        let outcome = try learner.tutor.addMyWord(NewMyWord(text: "Kubernetes", translation: "кубернетес", example: nil))
        let (card, result) = try learner.answerNext()

        #expect(preview.headword == "Kubernetes")
        #expect(preview.lookup == nil)
        #expect(preview.canAdd)
        #expect(outcome == .added(headword: "Kubernetes"))
        #expect(card.headword == "Kubernetes")
        #expect(card.kind == .mine)
        #expect(card.source == .mine)
        #expect(card.ipa == nil)
        #expect(card.partOfSpeech == .other)
        #expect(card.correctAnswer == "кубернетес")
        #expect(card.options.count == 4)
        #expect(result.mastery == 1)
    }
}
