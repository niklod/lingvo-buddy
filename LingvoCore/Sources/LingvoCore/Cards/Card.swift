import Foundation

public enum Direction: String, Sendable, Codable {
    case enToRu = "en_ru"
    case ruToEn = "ru_en"
}

public enum CardKind: String, Sendable, Codable {
    case new
    case review
    case mine
}

public enum CardSource: Sendable, Equatable {
    case rank(Int)
    case mine
}

/// One quiz card, ready to show. It is a value: answering returns a result
/// and never changes the card.
public struct Card: Sendable, Equatable {
    public let headword: String
    /// The word the learner sees: the headword for EN→RU, the translation for RU→EN.
    public let prompt: String
    public let direction: Direction
    public let kind: CardKind
    public let source: CardSource
    public let ipa: String?
    public let partOfSpeech: PartOfSpeech
    public let options: [String]
    public let correctIndex: Int
    public let example: String?
    public let mastery: Int

    public init(
        headword: String,
        prompt: String,
        direction: Direction,
        kind: CardKind,
        source: CardSource,
        ipa: String?,
        partOfSpeech: PartOfSpeech,
        options: [String],
        correctIndex: Int,
        example: String?,
        mastery: Int
    ) {
        self.headword = headword
        self.prompt = prompt
        self.direction = direction
        self.kind = kind
        self.source = source
        self.ipa = ipa
        self.partOfSpeech = partOfSpeech
        self.options = options
        self.correctIndex = correctIndex
        self.example = example
        self.mastery = mastery
    }

    public var correctAnswer: String {
        options[correctIndex]
    }
}

public enum CardDecision: Sendable, Equatable {
    case card(Card)
    case noCard(NoCardReason)

    public var card: Card? {
        if case .card(let card) = self { card } else { nil }
    }
}

public struct AnswerResult: Sendable, Equatable {
    public let outcome: AnswerOutcome
    public let correctIndex: Int
    public let correctAnswer: String
    /// This answer moved the word from learning to learned.
    public let becameLearned: Bool
    /// The word is learned after this answer: just now, or a passed review.
    public let isLearned: Bool
    public let mastery: Int

    public init(
        outcome: AnswerOutcome,
        correctIndex: Int,
        correctAnswer: String,
        becameLearned: Bool,
        isLearned: Bool,
        mastery: Int
    ) {
        self.outcome = outcome
        self.correctIndex = correctIndex
        self.correctAnswer = correctAnswer
        self.becameLearned = becameLearned
        self.isLearned = isLearned
        self.mastery = mastery
    }
}
