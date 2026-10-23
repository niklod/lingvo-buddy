import Foundation

/// The shape every saved translation has, like a dictionary translation: one variant with a
/// lower-case first letter. Quick add, the Dictionary window edit and CSV import all go through
/// this type, so the app layer never decides case or splitting.
public enum TranslationShape {
    /// A learner types or pastes variants with these; a machine translation also joins them with ", ".
    public static let separators: Set<Character> = [",", ";", "/"]

    /// Whether the learner ended a variant: the text has a separator, even when the part after it is blank.
    public static func hasSeparator(in text: String) -> Bool {
        text.contains(where: separators.contains)
    }

    /// The variants of the text in typed order: trimmed, case-normalized, without empty or repeated ones.
    public static func variants(in text: String) -> [String] {
        var seen: Set<String> = []
        return text.split(whereSeparator: separators.contains)
            .map { normalizedCase(String($0).trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    /// The variant a card saves from the text; `nil` when the text has no variant at all.
    public static func firstVariant(in text: String) -> String? {
        variants(in: text).first
    }

    /// Lowers the first letter (after leading quotes or punctuation), unless any later letter is upper
    /// case: "Москва" becomes "москва", «Спартак» becomes «спартак», and "США", "PhD" or "McKinsey" stay.
    public static func normalizedCase(_ variant: String) -> String {
        guard let index = variant.firstIndex(where: \.isLetter), variant[index].isUppercase else { return variant }
        let rest = variant[variant.index(after: index)...]
        guard !rest.contains(where: \.isUppercase) else { return variant }
        return String(variant[..<index]) + variant[index].lowercased() + String(rest)
    }
}
