import Foundation

/// The translation field of the Dictionary window edit. The field asks this while the learner types,
/// and `Tutor.editTranslation` enforces the same rule, so the field and Save never disagree.
public enum TranslationEditInput {
    /// What is wrong with the typed translation, or `nil`. Empty text is not a problem here: Save reports it as a missing translation.
    public static func problem(in text: String) -> LingvoCoreError? {
        TranslationShape.hasSeparator(in: text) ? .severalTranslations : nil
    }
}
