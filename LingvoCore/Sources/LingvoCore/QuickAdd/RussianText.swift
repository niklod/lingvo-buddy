import Foundation

/// How quick add tells Russian input from English and matches it against
/// dictionary translations.
enum RussianText {
    /// Cyrillic letters and no Latin ones. Mixed text stays on the English path,
    /// so the learner can predict what a typo does.
    static func isRussian(_ text: String) -> Bool {
        let letters = text.unicodeScalars.filter(\.properties.isAlphabetic)
        return letters.contains(where: isCyrillic) && !letters.contains(where: isLatin)
    }

    /// Learners often type «е» for «ё», and the dictionary spells some words
    /// either way, so both sides of a match go through this form.
    static func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "ё", with: "е")
    }

    private static func isCyrillic(_ scalar: Unicode.Scalar) -> Bool {
        (0x0400...0x052F).contains(scalar.value)
    }

    private static func isLatin(_ scalar: Unicode.Scalar) -> Bool {
        let latinRanges: [ClosedRange<UInt32>] = [0x41...0x5A, 0x61...0x7A, 0xC0...0x24F, 0x1E00...0x1EFF]
        return latinRanges.contains { $0.contains(scalar.value) }
    }
}
