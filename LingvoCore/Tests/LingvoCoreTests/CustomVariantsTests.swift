import LingvoCore
import Testing

@Suite("Custom variant bubbles of quick add")
struct CustomVariantsTests {
    @Test("a separator turns the typed variant into a selected lower-case bubble and empties the field")
    func separatorMakesBubble() {
        let (variants, choice) = CustomVariants().typing("Смыться,", choice: .custom)

        #expect(variants.bubbles == ["смыться"])
        #expect(variants.field == "")
        #expect(choice == .customBubble(0))
    }

    @Test("text typed after a bubble selects the field and is the variant Add saves")
    func remainingTextCountsOnAdd() {
        let (bubble, bubbleChoice) = CustomVariants().typing("Смыться,", choice: .custom)

        let (variants, choice) = bubble.typing("Удрать ", choice: bubbleChoice)

        #expect(variants.bubbles == ["смыться"])
        #expect(variants.field == "Удрать ")
        #expect(choice == .custom)
        #expect(variants.variant(for: choice) == "удрать")
        #expect(variants.variant(for: .customBubble(0)) == "смыться")
    }

    @Test("a paste with several variants makes a bubble for each, and the last one is selected")
    func pasteMakesBubbles() {
        let (variants, choice) = CustomVariants().typing("смыться, удрать; Слинять", choice: .custom)

        #expect(variants.bubbles == ["смыться", "удрать", "слинять"])
        #expect(variants.field == "")
        #expect(choice == .customBubble(2))
        #expect(variants.variant(for: choice) == "слинять")
    }

    @Test("a variant that is already a bubble makes no second one and selects the first; separators alone change nothing")
    func repeatedVariantSelectsExistingBubble() {
        let (two, _) = CustomVariants().typing("смыться, удрать,", choice: .custom)

        let (repeated, repeatedChoice) = two.typing("Смыться/", choice: .custom)
        let (blank, blankChoice) = two.typing(" , ", choice: .customBubble(1))

        #expect(repeated.bubbles == ["смыться", "удрать"])
        #expect(repeatedChoice == .customBubble(0))
        #expect(blank.bubbles == ["смыться", "удрать"])
        #expect(blank.field == "")
        #expect(blankChoice == .customBubble(1))
    }

    @Test("removing the selected bubble selects the one before it, or the next one when it was the first")
    func removingSelectedBubble() {
        let (three, _) = CustomVariants().typing("смыться, удрать, слинять,", choice: .custom)

        let (middle, middleChoice) = three.removing(at: 1, choice: .customBubble(1))
        let (first, firstChoice) = three.removing(at: 0, choice: .customBubble(0))

        #expect(middle.bubbles == ["смыться", "слинять"])
        #expect(middleChoice == .customBubble(0))
        #expect(first.bubbles == ["удрать", "слинять"])
        #expect(firstChoice == .customBubble(0))
    }

    @Test("removing the last bubble while it is selected selects the field")
    func removingOnlyBubble() {
        let (one, oneChoice) = CustomVariants().typing("смыться,", choice: .custom)

        let (none, choice) = one.removing(at: 0, choice: oneChoice)

        #expect(none.bubbles.isEmpty)
        #expect(choice == .custom)
    }

    @Test("removing another bubble keeps the selection on the same variant")
    func removingOtherBubble() {
        let (three, _) = CustomVariants().typing("смыться, удрать, слинять,", choice: .custom)

        let (later, laterChoice) = three.removing(at: 0, choice: .customBubble(2))
        let (_, earlierChoice) = three.removing(at: 2, choice: .customBubble(0))
        let (_, machineChoice) = three.removing(at: 0, choice: .machine(1))
        let (_, staleIndex) = three.removing(at: 5, choice: .customBubble(2))

        #expect(later.variant(for: laterChoice) == "слинять")
        #expect(earlierChoice == .customBubble(0))
        #expect(machineChoice == .machine(1))
        #expect(staleIndex == .customBubble(2))
    }

    @Test("a new word drops the bubbles and keeps the field text; the same word keeps both")
    func newWordDropsBubbles() throws {
        let tutor = try Fixture.tutor()
        let reluctant = try #require(try tutor.quickAddPreview("reluctant"))
        let spaced = try #require(try tutor.quickAddPreview("reluctant "))
        let other = try #require(try tutor.quickAddPreview("provide"))
        let (bubble, _) = CustomVariants().typing("неохотный,", choice: .custom)
        let (typed, _) = bubble.typing("вялый", choice: .custom)

        let sameWord = typed.afterPreview(from: reluctant, to: spaced)
        let newWord = typed.afterPreview(from: reluctant, to: other)

        #expect(sameWord == typed)
        #expect(newWord.bubbles.isEmpty)
        #expect(newWord.field == "вялый")
    }

    @Test("a machine suggestion never takes the selection from a custom bubble")
    func suggestionKeepsCustomBubble() {
        #expect(TranslationChoice.customBubble(0).afterSuggestion(typed: "") == .customBubble(0))
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

    @Test("clearing the field keeps the choice; an empty field has no variant to save")
    func emptyFieldHasNoVariant() {
        let (bubble, bubbleChoice) = CustomVariants().typing("смыться,", choice: .custom)

        let (variants, choice) = bubble.typing("", choice: bubbleChoice)

        #expect(choice == .customBubble(0))
        #expect(variants.variant(for: .custom) == "")
    }
}
