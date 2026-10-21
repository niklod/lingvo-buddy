import Foundation

public enum LingvoCoreError: Error, Equatable, LocalizedError {
    case invalidDictionary(String)
    case unknownWord(String)
    case invalidChoice(Int)
    case invalidTimeOfDay(hour: Int, minute: Int)

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
        }
    }
}
