import Foundation

public enum LingvoCoreError: Error, Equatable, LocalizedError {
    case invalidDictionary(String)
    case unknownWord(String)
    case invalidChoice(Int)
    case invalidTimeOfDay(hour: Int, minute: Int)
    case invalidInterval(TimeInterval)
    case emptyWord
    case missingTranslation(String)
    case tooLong(Field, limit: Int)
    /// Only my words can be deleted; dictionary words can be reset instead.
    case notMyWord(String)

    /// Quick-add input fields, for `tooLong`.
    public enum Field: String, Sendable, Equatable {
        case word, translation, example
    }

    public var errorDescription: String? {
        switch self {
        case .invalidDictionary(let reason):
            "The dictionary is not valid: \(reason)"
        case .unknownWord(let headword):
            "The word \"\(headword)\" is not in the dictionary."
        case .invalidChoice(let index):
            "Option \(index) does not exist on this card."
        case .invalidTimeOfDay(let hour, let minute):
            "\(hour):\(minute) is not a valid time of day."
        case .invalidInterval(let seconds):
            "A card interval of \(seconds) s is not valid; it must be positive."
        case .emptyWord:
            "Type a word to add."
        case .missingTranslation(let word):
            "Type a translation for \"\(word)\"."
        case .tooLong(let field, let limit):
            "The \(field.rawValue) is too long: at most \(limit) characters."
        case .notMyWord(let headword):
            "\"\(headword)\" is a dictionary word, not one of your words: it cannot be deleted."
        }
    }
}
