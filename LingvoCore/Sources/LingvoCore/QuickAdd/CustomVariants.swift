import Foundation

/// The learner's own variants in quick add: the bubbles a separator finished, and the text still in the field.
/// One value serves the custom translation field and the "English word for the card" field.
public struct CustomVariants: Equatable, Sendable {
    /// A long paste must not fill the panel with bubbles; the learner picks one of them anyway.
    public static let maxVariants = 10

    public private(set) var bubbles: [String] = []
    public private(set) var field = ""

    public init() {}

    /// New text in the field. A separator turns every variant in it into a bubble, so typing "смыться,"
    /// and pasting "смыться, удрать, слинять" work the same way; the newest bubble is selected.
    /// A variant too long for a card stays in the field, so Add reports it.
    public func typing(_ text: String, choice: TranslationChoice) -> (variants: CustomVariants, choice: TranslationChoice) {
        guard TranslationShape.hasSeparator(in: text) else { return typingVariant(text, choice: choice) }
        var next = self
        var selected = choice
        var indices = Dictionary(bubbles.enumerated().map { ($0.element, $0.offset) }, uniquingKeysWith: { first, _ in first })
        var tooLong: [String] = []
        for variant in TranslationShape.variants(in: text) {
            if variant.count > NewMyWord.maxTranslationLength {
                tooLong.append(variant)
            } else if let index = indices[variant] {
                selected = .customBubble(index)
            } else if next.bubbles.count < Self.maxVariants {
                indices[variant] = next.bubbles.count
                next.bubbles.append(variant)
                selected = .customBubble(next.bubbles.count - 1)
            }
        }
        next.field = tooLong.joined(separator: ", ")
        return (next, tooLong.isEmpty ? selected : .custom)
    }

    /// Bubbles typed for the previous word must not stay selectable for a new one. The field text
    /// stays: fixing a typo in the word must not erase the translation.
    public func droppingBubbles() -> CustomVariants {
        var fresh = CustomVariants()
        fresh.field = field
        return fresh
    }

    /// The × of a bubble. A selected bubble hands the selection to its neighbour (the one before it
    /// first), or to the field when no bubble is left; any other choice stays on the same variant.
    public func removing(at index: Int, choice: TranslationChoice) -> (variants: CustomVariants, choice: TranslationChoice) {
        guard bubbles.indices.contains(index) else { return (self, choice) }
        var next = self
        next.bubbles.remove(at: index)
        guard case .customBubble(let selected) = choice else { return (next, choice) }
        if selected > index { return (next, .customBubble(selected - 1)) }
        if selected < index { return (next, choice) }
        if next.bubbles.isEmpty { return (next, .custom) }
        return (next, .customBubble(max(index - 1, 0)))
    }

    /// The variant the card gets for a custom choice: the picked bubble, or else the field text, which
    /// counts on Add without a separator after it. Empty when the field is empty or the bubble is gone.
    public func variant(for choice: TranslationChoice) -> String {
        switch choice {
        case .customBubble(let index): bubbles.indices.contains(index) ? bubbles[index] : ""
        case .custom, .dictionary, .machine: TranslationShape.normalizedCase(Self.trimmed(field))
        }
    }

    private func typingVariant(_ text: String, choice: TranslationChoice) -> (variants: CustomVariants, choice: TranslationChoice) {
        var next = self
        next.field = text
        guard Self.trimmed(text).isEmpty else {
            // The text the learner is typing is the newest variant, so it wins over an older pick.
            return (next, .custom)
        }
        // Deleting the text leaves no variant in the field, so the newest bubble takes the selection.
        let deletedText = choice == .custom && !Self.trimmed(field).isEmpty
        guard deletedText, !bubbles.isEmpty else { return (next, choice) }
        return (next, .customBubble(bubbles.count - 1))
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
