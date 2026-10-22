import Foundation

/// What the learner submits from the quick-add panel.
public struct NewMyWord: Sendable, Equatable {
    public static let maxWordLength = 64
    public static let maxTranslationLength = 80
    public static let maxExampleLength = 300
    public static let maxIPALength = 64

    public let text: String
    /// A dictionary translation the learner picked, or their own.
    public let translation: String
    /// "Where I saw it": becomes the card's example sentence.
    public let example: String?

    public init(text: String, translation: String, example: String?) {
        self.text = text
        self.translation = translation
        self.example = example
    }

    /// Trimmed copy; blank example becomes `nil`.
    func validated() throws -> NewMyWord {
        let text = Self.trimmed(text)
        let translation = Self.trimmed(translation)
        let example = example.map(Self.trimmed).flatMap { $0.isEmpty ? nil : $0 }
        guard !text.isEmpty else { throw LingvoCoreError.emptyWord }
        guard !translation.isEmpty else { throw LingvoCoreError.missingTranslation(text) }
        try Self.check(text, field: .word, limit: Self.maxWordLength)
        try Self.check(translation, field: .translation, limit: Self.maxTranslationLength)
        if let example {
            try Self.check(example, field: .example, limit: Self.maxExampleLength)
        }
        return NewMyWord(text: text, translation: translation, example: example)
    }

    private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func check(_ value: String, field: LingvoCoreError.Field, limit: Int) throws {
        guard value.count <= limit else { throw LingvoCoreError.tooLong(field, limit: limit) }
    }
}

public enum AddWordOutcome: Sendable, Equatable {
    case added(headword: String)
    /// Nothing changed: the word is already in My words, learning or learned.
    case alreadyAdded(WordStanding)
}
