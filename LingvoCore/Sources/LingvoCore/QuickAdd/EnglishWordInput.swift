import Foundation

/// The "English word for the card" field of quick add. The panel asks this while the learner types,
/// and `Tutor.addMyWord` enforces the same rule, so the field and Add never disagree.
public enum EnglishWordInput {
    /// What is wrong with the typed word, or `nil`. Empty text is not a problem: the panel treats it as "not typed yet".
    public static func problem(in text: String) -> LingvoCoreError? {
        let word = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return RussianText.isRussian(word) ? .notEnglishWord(word) : nil
    }
}
