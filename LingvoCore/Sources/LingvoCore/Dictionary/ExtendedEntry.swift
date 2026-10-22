import Foundation

/// What the extended dictionary (cleaned Wiktionary data) says about an English word
/// the bundled dictionary lacks. It has no rank and no tier and never feeds quizzes.
public struct ExtendedEntry: Sendable, Equatable {
    /// Joins translations in the SQLite column and in the committed text source.
    static let translationSeparator: Character = "|"

    public let headword: String
    public let partOfSpeech: PartOfSpeech
    public let ipa: String?
    /// Short Russian translations, best first; up to five.
    public let translations: [String]
    public let example: String?
    /// The Russian translation of `example`; only with an `example`.
    public let russianExample: String?

    public init(
        headword: String,
        partOfSpeech: PartOfSpeech,
        ipa: String? = nil,
        translations: [String],
        example: String? = nil,
        russianExample: String? = nil
    ) {
        self.headword = headword
        self.partOfSpeech = partOfSpeech
        self.ipa = ipa
        self.translations = translations
        self.example = example
        self.russianExample = russianExample
    }
}

/// What the extended dictionary says about a Russian word: short English translations, best first.
/// Only words the bundled dictionary does not translate are in it.
public struct ExtendedRussianEntry: Sendable, Equatable {
    public let word: String
    public let translations: [String]

    public init(word: String, translations: [String]) {
        self.word = word
        self.translations = translations
    }
}
