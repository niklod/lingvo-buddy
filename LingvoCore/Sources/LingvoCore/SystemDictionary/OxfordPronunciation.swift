import Foundation

/// Converts the pronunciation notation of the New Oxford American Dictionary ("skəˈdad(ə)l")
/// to American IPA in slashes ("/skəˈdædəl/").
enum OxfordPronunciation {
    private static let primaryStress: Unicode.Scalar = "ˈ"
    private static let secondaryStress: Unicode.Scalar = "ˌ"
    private static let schwa: Unicode.Scalar = "ə"
    private static let rhotic: Unicode.Scalar = "r"

    /// Longest first: a sequence must win over its first letter.
    private static let table: [(notation: String, ipa: String)] = [
        ("T\u{35F}H", "ð"), ("o\u{35D}o", "ʊ"), ("o\u{35E}o", "u"),
        ("CH", "tʃ"), ("SH", "ʃ"), ("ZH", "ʒ"), ("TH", "θ"), ("NG", "ŋ"),
        ("ou", "aʊ"), ("oi", "ɔɪ"),
        ("ä", "ɑ"), ("ô", "ɔ"), ("ē", "i"), ("ī", "aɪ"), ("ō", "oʊ"), ("ā", "eɪ"), ("ū", "u"),
        ("ă", "æ"), ("ĕ", "ɛ"), ("ĭ", "ɪ"), ("ŏ", "ɑ"), ("ŭ", "ʌ"),
        ("a", "æ"), ("e", "ɛ"), ("i", "ɪ"), ("o", "ɑ"), ("u", "ʌ"),
        ("y", "j"), ("j", "dʒ"), ("g", "ɡ"),
    ]

    /// Only the vowels count for the stress rule below; the table output starts with a vowel letter or not.
    private static let vowelSigns: Set<Character> = ["æ", "ɛ", "ɪ", "ɑ", "ʌ", "ʊ", "u", "ɔ", "i", "e", "a", "o"]

    private static let vowelNotation: Set<Unicode.Scalar> = Set("aeiouäôēīōāūəăĕĭŏŭ".unicodeScalars)

    /// `nil` when nothing is left after the first spelling variant.
    static func ipa(_ notation: String) -> String? {
        // Several spellings follow each other after commas ("ant, änt"); the first is the main one.
        let first = notation.split(separator: ",").first.map(String.init) ?? ""
        // Parentheses mark optional sounds; the IPA keeps them as ordinary sounds.
        let cleaned = first
            .precomposedStringWithCanonicalMapping
            .filter { $0 != "(" && $0 != ")" }
            .trimmingCharacters(in: .whitespaces)
        let scalars = Array(cleaned.unicodeScalars)
        guard !scalars.isEmpty else { return nil }
        let converted = convert(scalars)
        return converted.isEmpty ? nil : "/\(converted)/"
    }

    private static func convert(_ scalars: [Unicode.Scalar]) -> String {
        var output = ""
        var index = 0
        // A word with one syllable carries no stress mark; its only vowel is the stressed one.
        var stressed = !scalars.contains { $0 == primaryStress || $0 == secondaryStress }
        while index < scalars.count {
            let scalar = scalars[index]
            if scalar == primaryStress || scalar == secondaryStress {
                stressed = true
                output.unicodeScalars.append(scalar)
                index += 1
            } else if scalar == schwa {
                let followedByR = closesWithR(scalars, from: index + 1)
                output += rhoticOrPlain(stressed: stressed, followedByR: followedByR)
                index += followedByR ? 2 : 1
                stressed = false
            } else if let (ipa, length) = match(scalars, at: index) {
                output += ipa
                index += length
                if ipa.contains(where: vowelSigns.contains) { stressed = false }
            } else {
                output.unicodeScalars.append(scalar)
                index += 1
            }
        }
        return output
    }

    /// "ər" is one r-coloured vowel only when the r closes the syllable: in "əˈfem(ə)rəl" the r starts the next one.
    private static func closesWithR(_ scalars: [Unicode.Scalar], from index: Int) -> Bool {
        guard index < scalars.count, scalars[index] == rhotic else { return false }
        guard index + 1 < scalars.count else { return true }
        return !vowelNotation.contains(scalars[index + 1])
    }

    /// NOAD writes one sign for the stressed "ʌ" and the unstressed "ə"; "ər" is the r-coloured vowel.
    private static func rhoticOrPlain(stressed: Bool, followedByR: Bool) -> String {
        switch (stressed, followedByR) {
        case (true, true): "ɝ"
        case (true, false): "ʌ"
        case (false, true): "ɚ"
        case (false, false): "ə"
        }
    }

    private static func match(_ scalars: [Unicode.Scalar], at index: Int) -> (ipa: String, length: Int)? {
        for entry in table {
            let notation = Array(entry.notation.precomposedStringWithCanonicalMapping.unicodeScalars)
            guard index + notation.count <= scalars.count,
                  Array(scalars[index..<index + notation.count]) == notation else { continue }
            return (entry.ipa, notation.count)
        }
        return nil
    }
}
