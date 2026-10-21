import Foundation

public enum LingvoCoreError: Error, Equatable, LocalizedError {
    case invalidDictionary(String)
    case unknownWord(String)
    case invalidChoice(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidDictionary(let reason):
            "The dictionary is not valid: \(reason)"
        case .unknownWord(let headword):
            "The word \"\(headword)\" is not in the dictionary."
        case .invalidChoice(let index):
            "Option \(index) does not exist on this card."
        }
    }
}
