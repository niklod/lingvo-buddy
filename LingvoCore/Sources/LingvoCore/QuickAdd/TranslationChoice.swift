import Foundation

/// Which translation goes on the card.
public enum TranslationChoice: Equatable, Sendable {
    /// Index into the dictionary translations.
    case dictionary(Int)
    /// The text in the custom field (translation or English word), as opposed to a finished bubble.
    case custom
    /// Index into the custom bubbles: variants the learner finished with a separator.
    case customBubble(Int)
    /// Index into the machine translation bubbles: the card's translation, or the English word for Russian input.
    case machine(Int)

    /// The first dictionary translation is preselected for each new word; a word without one needs the custom text.
    public static func preselected(translations: [String]) -> TranslationChoice {
        translations.isEmpty ? .custom : .dictionary(0)
    }

    /// When a suggestion arrives: text the learner typed while waiting wins over it, and so do the
    /// bubbles they finished, even when the field is empty again.
    public func afterSuggestion(typed: String, hasCustomBubbles: Bool) -> TranslationChoice {
        let typedNothing = typed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !hasCustomBubbles
        return self == .custom && typedNothing ? .machine(0) : self
    }

    /// A machine bubble picked for the previous word must not stay selected as if it were for the new one.
    public var droppingMachine: TranslationChoice {
        isMachine ? .custom : self
    }

    public var isMachine: Bool {
        if case .machine = self { true } else { false }
    }

    /// The field or one of the bubbles typed in it.
    public var isCustom: Bool {
        switch self {
        case .custom, .customBubble: true
        case .dictionary, .machine: false
        }
    }

    /// The variant the card gets. An index that no longer points at a bubble gives "", so Add refuses
    /// instead of saving the text of another source.
    public func variant(translations: [String], machineBubbles: [String], custom: CustomVariants) -> String {
        switch self {
        case .dictionary(let index): translations.indices.contains(index) ? translations[index] : ""
        case .machine(let index): machineBubbles.indices.contains(index) ? machineBubbles[index] : ""
        case .custom, .customBubble: custom.variant(for: self)
        }
    }
}

extension QuickAddPreview {
    /// The dictionary headword for English input (so "Reluctant" and "reluctant"
    /// keep the choice), the trimmed text for Russian input.
    public var typedWord: String { russianText ?? headword }

    /// The learner's choices survive a preview of the same word (a trailing space) and reset for a new one.
    public static func keepsChoices(from previous: QuickAddPreview?, to next: QuickAddPreview?) -> Bool {
        previous?.typedWord == next?.typedWord
    }
}
