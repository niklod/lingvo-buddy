import Foundation

public enum PartOfSpeech: String, Sendable, Codable, CaseIterable {
    case noun, verb, adjective, adverb, pronoun, preposition, conjunction
    case determiner, numeral, interjection, other
}

public enum DictionaryTier: String, Sendable, Codable, CaseIterable {
    /// Full card data: example and synonym group are present.
    case quiz
    /// Quick-add lookup only: no example, no synonym group.
    case lookup
}

public enum Language: String, Sendable, Codable {
    case russian = "ru"
}

public struct DictionaryEntry: Sendable, Equatable {
    public let headword: String
    public let rank: Int
    public let partOfSpeech: PartOfSpeech
    public let ipa: String?
    public let example: String?
    /// The Russian translation of `example`; only with an `example`.
    public let russianExample: String?
    public let synonymGroup: String?
    public let tier: DictionaryTier
    /// Ordered by preference: the first translation is the one a card shows.
    public let translations: [Language: [String]]

    public init(
        headword: String,
        rank: Int,
        partOfSpeech: PartOfSpeech,
        ipa: String?,
        example: String?,
        synonymGroup: String?,
        tier: DictionaryTier,
        translations: [Language: [String]],
        russianExample: String? = nil
    ) {
        self.headword = headword
        self.rank = rank
        self.partOfSpeech = partOfSpeech
        self.ipa = ipa
        self.example = example
        self.russianExample = russianExample
        self.synonymGroup = synonymGroup
        self.tier = tier
        self.translations = translations
    }

    public var primaryRussian: String? {
        translations[.russian]?.first
    }
}
