import LingvoCore
import Testing

@Suite("The translation edit field")
struct TranslationEditInputTests {
    @Test("a separator is a problem, and the message is the card rule")
    func separatorIsAProblem() {
        #expect(TranslationEditInput.problem(in: "смыться, удрать") == .severalTranslations)
        #expect(TranslationEditInput.problem(in: "a;") == .severalTranslations)
        #expect(TranslationEditInput.problem(in: "/") == .severalTranslations)
        #expect(TranslationEditInput.problem(in: "a;")?.localizedDescription == "One translation per card.")
    }

    @Test("one variant, an abbreviation and empty text are not a problem here")
    func oneVariantPasses() {
        #expect(TranslationEditInput.problem(in: "смыться") == nil)
        #expect(TranslationEditInput.problem(in: " США ") == nil)
        #expect(TranslationEditInput.problem(in: "  ") == nil)
    }

    @Test("Save refuses the text that the field refuses, with the same error")
    func editTranslationAgrees() throws {
        let learner = try Learner(settings: LearningSettings(direction: .enToRu))
        _ = try learner.tutor.addMyWord(NewMyWord(text: "skedaddle", translation: "смыться", example: nil))
        let typed = "смыться, удрать"
        #expect(TranslationEditInput.problem(in: typed) == .severalTranslations)

        #expect(throws: LingvoCoreError.severalTranslations) {
            try learner.tutor.editTranslation("skedaddle", to: typed)
        }
    }
}
