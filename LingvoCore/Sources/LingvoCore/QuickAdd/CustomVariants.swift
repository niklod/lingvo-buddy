import Foundation

/// The learner's own variants in quick add: the bubbles a separator finished, and the text still in the field.
/// One value serves the custom translation field and the "English word for the card" field.
public struct CustomVariants: Equatable, Sendable {
    public private(set) var bubbles: [String] = []
    public private(set) var field = ""

    public init() {}

    /// New text in the field. A separator turns every variant in it into a bubble, so typing "смыться,"
    /// and pasting "смыться, удрать, слинять" work the same way; the newest bubble is selected.
    public func typing(_ text: String, choice: TranslationChoice) -> (CustomVariants, TranslationChoice) {
        var next = self
        guard TranslationShape.hasSeparator(in: text) else {
            next.field = text
            // The text the learner is typing is the newest variant, so it wins over an older pick.
            return (next, Self.isBlank(text) ? choice : .custom)
        }
        next.field = ""
        var selected = choice
        for variant in TranslationShape.variants(in: text) {
            if let index = next.bubbles.firstIndex(of: variant) {
                selected = .customBubble(index)
            } else {
                next.bubbles.append(variant)
                selected = .customBubble(next.bubbles.count - 1)
            }
        }
        return (next, selected)
    }

    /// Bubbles typed for the previous word must not stay selectable for a new one. The field text
    /// stays, as it always has: fixing a typo in the word must not erase the translation.
    public func afterPreview(from previous: QuickAddPreview?, to next: QuickAddPreview?) -> CustomVariants {
        guard !QuickAddPreview.keepsChoices(from: previous, to: next) else { return self }
        var fresh = CustomVariants()
        fresh.field = field
        return fresh
    }

    /// The × of a bubble. A selected bubble hands the selection to its neighbour (the one before it
    /// first), or to the field when no bubble is left; any other choice stays on the same variant.
    public func removing(at index: Int, choice: TranslationChoice) -> (CustomVariants, TranslationChoice) {
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
    /// counts on Add without a separator after it. Empty when the field is empty.
    public func variant(for choice: TranslationChoice) -> String {
        if case .customBubble(let index) = choice, bubbles.indices.contains(index) { return bubbles[index] }
        return TranslationShape.variants(in: field).first ?? ""
    }

    private static func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
