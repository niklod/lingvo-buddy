import Foundation

/// Which translation goes on the card.
public enum TranslationChoice: Equatable, Sendable {
    /// Index into the dictionary translations.
    case dictionary(Int)
    /// The "+ custom variant" text.
    case custom
    /// Index into the machine translation bubbles: the card's translation, or the English word for Russian input.
    case machine(Int)

    /// The first dictionary translation is preselected for each new word; a word without one needs the custom text.
    public static func preselected(translations: [String]) -> TranslationChoice {
        translations.isEmpty ? .custom : .dictionary(0)
    }

    /// When a suggestion arrives: text the learner typed while waiting wins over it.
    public func afterSuggestion(typed: String) -> TranslationChoice {
        self == .custom && typed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .machine(0) : self
    }

    /// A machine bubble picked for the previous word must not stay selected as if it were for the new one.
    public var droppingMachine: TranslationChoice {
        if case .machine = self { .custom } else { self }
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
