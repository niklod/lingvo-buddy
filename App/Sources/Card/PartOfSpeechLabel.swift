import LingvoCore

extension PartOfSpeech {
    /// The word class as cards and quick add show it.
    var label: String {
        switch self {
        case .noun: String(localized: "noun")
        case .verb: String(localized: "verb")
        case .adjective: String(localized: "adjective")
        case .adverb: String(localized: "adverb")
        case .pronoun: String(localized: "pronoun")
        case .preposition: String(localized: "preposition")
        case .conjunction: String(localized: "conjunction")
        case .determiner: String(localized: "determiner")
        case .numeral: String(localized: "numeral")
        case .interjection: String(localized: "interjection")
        case .other: String(localized: "other")
        }
    }
}
