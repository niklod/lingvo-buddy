import LingvoCore
import Testing

@Suite("Custom variant bubbles of quick add")
struct CustomVariantsTests {
    @Test("a separator turns the typed variant into a selected lower-case bubble and empties the field")
    func separatorMakesBubble() {
        let (variants, choice) = CustomVariants().typing("Смыться,", choice: .custom)

        #expect((variants.bubbles, variants.field, choice) == (["смыться"], "", .customBubble(0)))
    }

    @Test("text typed after a bubble selects the field and is the variant Add saves")
    func remainingTextCountsOnAdd() {
        let (bubble, bubbleChoice) = CustomVariants().typing("Смыться,", choice: .custom)

        let (variants, choice) = bubble.typing("Удрать ", choice: bubbleChoice)

        #expect(
            (variants.bubbles, variants.field, choice, variants.variant(for: choice), variants.variant(for: .customBubble(0)))
                == (["смыться"], "Удрать ", .custom, "удрать", "смыться")
        )
    }

    @Test("a paste with several variants makes a bubble for each, and the last one is selected")
    func pasteMakesBubbles() {
        let (variants, choice) = CustomVariants().typing("смыться, удрать; Слинять", choice: .custom)

        #expect(
            (variants.bubbles, variants.field, choice, variants.variant(for: choice))
                == (["смыться", "удрать", "слинять"], "", .customBubble(2), "слинять")
        )
    }

    @Test("a paste of more variants than the cap keeps the first ones only")
    func pasteIsCapped() {
        let words = (1...50).map { "вариант\($0)" }

        let (variants, choice) = CustomVariants().typing(words.joined(separator: ", "), choice: .custom)

        let cap = CustomVariants.maxVariants
        #expect((variants.bubbles, variants.field, choice) == (Array(words.prefix(cap)), "", .customBubble(cap - 1)))
    }

    @Test("a variant longer than a card translation stays in the field, so Add reports it as too long")
    func overlongVariantStaysInField() {
        let long = String(repeating: "о", count: NewMyWord.maxTranslationLength + 1)

        let (variants, choice) = CustomVariants().typing("смыться, \(long),", choice: .custom)

        #expect((variants.bubbles, variants.field, choice) == (["смыться"], long, .custom))
    }

    @Test("a variant that is already a bubble makes no second one and selects the first; separators alone change nothing")
    func repeatedVariantSelectsExistingBubble() {
        let (two, _) = CustomVariants().typing("смыться, удрать,", choice: .custom)

        let (repeated, repeatedChoice) = two.typing("Смыться/", choice: .custom)
        let (blank, blankChoice) = two.typing(" , ", choice: .customBubble(1))

        #expect((repeated.bubbles, repeatedChoice) == (["смыться", "удрать"], .customBubble(0)))
        #expect((blank.bubbles, blank.field, blankChoice) == (["смыться", "удрать"], "", .customBubble(1)))
    }

    @Test("removing the selected bubble selects the one before it, or the next one when it was the first")
    func removingSelectedBubble() {
        let (three, _) = CustomVariants().typing("смыться, удрать, слинять,", choice: .custom)

        let (middle, middleChoice) = three.removing(at: 1, choice: .customBubble(1))
        let (first, firstChoice) = three.removing(at: 0, choice: .customBubble(0))

        #expect((middle.bubbles, middleChoice) == (["смыться", "слинять"], .customBubble(0)))
        #expect((first.bubbles, firstChoice) == (["удрать", "слинять"], .customBubble(0)))
    }

    @Test("removing the last bubble while it is selected selects the field")
    func removingOnlyBubble() {
        let (one, oneChoice) = CustomVariants().typing("смыться,", choice: .custom)

        let (none, choice) = one.removing(at: 0, choice: oneChoice)

        #expect((none.bubbles, choice) == ([], .custom))
    }

    @Test("removing another bubble keeps the selection on the same variant")
    func removingOtherBubble() {
        let (three, _) = CustomVariants().typing("смыться, удрать, слинять,", choice: .custom)

        let (later, laterChoice) = three.removing(at: 0, choice: .customBubble(2))
        let (_, earlierChoice) = three.removing(at: 2, choice: .customBubble(0))
        let (_, machineChoice) = three.removing(at: 0, choice: .machine(1))
        let (_, staleIndex) = three.removing(at: 5, choice: .customBubble(2))

        #expect(
            (later.variant(for: laterChoice), earlierChoice, machineChoice, staleIndex)
                == ("слинять", .customBubble(0), .machine(1), .customBubble(2))
        )
    }

    @Test("dropping the bubbles keeps the field text: fixing a typo in the word must not erase the translation")
    func droppingBubblesKeepsField() {
        let (bubble, _) = CustomVariants().typing("неохотный,", choice: .custom)
        let (typed, _) = bubble.typing("вялый", choice: .custom)

        let dropped = typed.droppingBubbles()

        #expect((dropped.bubbles, dropped.field) == ([], "вялый"))
    }

    @Test("a new word, a cleared word and another Russian word reset the choices; the same word keeps them")
    func choicesResetForNewWord() throws {
        let tutor = try Fixture.tutor()
        let reluctant = try #require(try tutor.quickAddPreview("reluctant"))
        let spaced = try #require(try tutor.quickAddPreview("reluctant "))
        let other = try #require(try tutor.quickAddPreview("provide"))
        let russian = try #require(try tutor.quickAddPreview("болтун"))
        let otherRussian = try #require(try tutor.quickAddPreview("болтунья"))

        #expect(
            [
                QuickAddPreview.keepsChoices(from: reluctant, to: spaced),
                QuickAddPreview.keepsChoices(from: reluctant, to: other),
                QuickAddPreview.keepsChoices(from: reluctant, to: nil),
                QuickAddPreview.keepsChoices(from: russian, to: otherRussian),
            ] == [true, false, false, false]
        )
    }

    @Test("a machine suggestion never takes the selection from a custom bubble")
    func suggestionKeepsCustomBubble() {
        #expect(TranslationChoice.customBubble(0).afterSuggestion(typed: "", hasCustomBubbles: true) == .customBubble(0))
        #expect(TranslationChoice.customBubble(0).droppingMachine == .customBubble(0))
    }

    @Test("the English word field makes English bubbles; a Cyrillic bubble is still refused")
    func englishWordBubbles() {
        let (english, englishChoice) = CustomVariants().typing("Chatterbox, ", choice: .custom)
        let (russian, russianChoice) = english.typing("болтун,", choice: englishChoice)

        #expect(english.variant(for: englishChoice) == "chatterbox")
        #expect(EnglishWordInput.problem(in: english.variant(for: englishChoice)) == nil)
        #expect(EnglishWordInput.problem(in: russian.variant(for: russianChoice)) == .notEnglishWord("болтун"))
    }

    @Test("clearing the field keeps a picked bubble; an empty field has no variant to save")
    func emptyFieldHasNoVariant() {
        let (bubble, bubbleChoice) = CustomVariants().typing("смыться,", choice: .custom)

        let (variants, choice) = bubble.typing("", choice: bubbleChoice)

        #expect((choice, variants.variant(for: .custom)) == (.customBubble(0), ""))
    }

    @Test("deleting the field text while it is selected selects the newest bubble")
    func deletingFieldSelectsLastBubble() {
        let (two, _) = CustomVariants().typing("смыться, удрать,", choice: .custom)
        let (typing, typingChoice) = two.typing("сл", choice: .customBubble(1))

        let (deleted, choice) = typing.typing(" ", choice: typingChoice)

        #expect((deleted.field, choice) == (" ", .customBubble(1)))
    }

    @Test("a stale bubble index has no variant, even with text in the field")
    func staleBubbleHasNoVariant() {
        let (one, _) = CustomVariants().typing("смыться,", choice: .custom)
        let (typed, _) = one.typing("удрать", choice: .custom)

        #expect(typed.variant(for: .customBubble(5)) == "")
    }
}
