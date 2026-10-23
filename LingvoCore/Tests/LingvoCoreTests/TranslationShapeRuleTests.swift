import LingvoCore
import Testing

/// The rule that the quick-add panel (bubbles, typed text, edit field) reuses; the `Tutor` save paths are in `TranslationShapeTests`.
@Suite("Translation shape rule")
struct TranslationShapeRuleTests {
    @Test("variants are split on every separator, trimmed, lower-cased and de-duplicated")
    func variants() {
        #expect(TranslationShape.variants(in: "Сматываться, смотаться") == ["сматываться", "смотаться"])
        #expect(TranslationShape.variants(in: " а ;б/ в ,, Б; а ") == ["а", "б", "в"])
        #expect(TranslationShape.variants(in: "США, ООН") == ["США", "ООН"])
        #expect(TranslationShape.variants(in: " , ; ").isEmpty)
        #expect(TranslationShape.variants(in: "слово") == ["слово"])
    }

    @Test("the first letter is lowered unless any later letter is upper case")
    func normalizedCase() {
        let typed = ["Москва", "Я", "iPhone", "", "США", "API", "PhD", "McKinsey", "WiFi"]
        let shaped = ["москва", "я", "iPhone", "", "США", "API", "PhD", "McKinsey", "WiFi"]

        #expect(typed.map(TranslationShape.normalizedCase) == shaped)
    }

    @Test("the first letter after leading quotes or punctuation is lowered")
    func normalizedCaseAfterQuotes() {
        let typed = ["«Спартак»", "\"Сматываться\"", "(Слово)", "«ООН»"]
        let shaped = ["«спартак»", "\"сматываться\"", "(слово)", "«ООН»"]

        #expect(typed.map(TranslationShape.normalizedCase) == shaped)
    }

    @Test("the first variant is the one a card saves")
    func firstVariant() {
        #expect(TranslationShape.firstVariant(in: " , Смыться; удрать") == "смыться")
        #expect(TranslationShape.firstVariant(in: " ; ") == nil)
    }

    @Test("a separator is found even when no variant is typed yet")
    func hasSeparator() {
        #expect(TranslationShape.hasSeparator(in: "a, b"))
        #expect(TranslationShape.hasSeparator(in: "a;"))
        #expect(TranslationShape.hasSeparator(in: "/"))
        #expect(!TranslationShape.hasSeparator(in: "один вариант"))
    }
}
