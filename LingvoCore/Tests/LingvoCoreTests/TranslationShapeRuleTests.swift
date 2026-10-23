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

    @Test("the first letter is lowered unless the second letter is upper case too")
    func normalizedCase() {
        #expect(TranslationShape.normalizedCase("Москва") == "москва")
        #expect(TranslationShape.normalizedCase("США") == "США")
        #expect(TranslationShape.normalizedCase("API") == "API")
        #expect(TranslationShape.normalizedCase("Я") == "я")
        #expect(TranslationShape.normalizedCase("iPhone") == "iPhone")
        #expect(TranslationShape.normalizedCase("") == "")
    }

    @Test("a separator is found even when no variant is typed yet")
    func hasSeparator() {
        #expect(TranslationShape.hasSeparator(in: "a, b"))
        #expect(TranslationShape.hasSeparator(in: "a;"))
        #expect(TranslationShape.hasSeparator(in: "/"))
        #expect(!TranslationShape.hasSeparator(in: "один вариант"))
    }
}
