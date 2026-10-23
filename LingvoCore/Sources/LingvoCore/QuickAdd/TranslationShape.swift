import Foundation

/// The shape every saved translation has, like a dictionary translation: one variant with a
/// lower-case first letter. Quick add, the Dictionary window edit and CSV import all go through
/// this type, so the app layer never decides case or splitting.
public enum TranslationShape {
    /// A learner types or pastes variants with these; a machine translation also joins them with ", ".
    public static let separators: Set<Character> = [",", ";", "/"]

    /// Whether the text holds more than one variant, even when the parts around the separator are blank.
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

    /// Lowers the first letter, unless the second letter is upper case too: "Москва" becomes "москва",
    /// and an abbreviation such as "США" or "API" stays as it is.
    public static func normalizedCase(_ variant: String) -> String {
        guard let first = variant.first, first.isUppercase else { return variant }
        if let second = variant.dropFirst().first, second.isUppercase { return variant }
        return first.lowercased() + variant.dropFirst()
    }
}
