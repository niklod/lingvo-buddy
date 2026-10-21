import LingvoCore
import SwiftUI

/// Everything the quiz card view shows. A value, so snapshot states are plain data.
struct QuizCardState: Equatable {
    struct Answer: Equatable {
        /// `nil` when the learner pressed "Don't know".
        let pickedIndex: Int?
        let result: AnswerResult
    }

    let card: Card
    let answer: Answer?

    var isAnswered: Bool { answer != nil }

    var mastery: Int { answer?.result.mastery ?? card.mastery }
}

enum OptionAppearance {
    case idle
    case correct
    case pickedWrong
    case faded
}

extension QuizCardState {
    func appearance(ofOption index: Int) -> OptionAppearance {
        guard let answer else { return .idle }
        if index == answer.result.correctIndex { return .correct }
        if index == answer.pickedIndex { return .pickedWrong }
        return .faded
    }

    var kindLabel: LocalizedStringKey {
        switch card.kind {
        case .new: "New"
        case .review: "Review"
        case .mine: "My word"
        }
    }

    var sourceLabel: String {
        switch card.source {
        case .rank(let rank):
            String(localized: "Top‑\(String(Self.tierCeiling(for: rank))) · #\(String(rank))")
        case .mine:
            String(localized: "My words")
        }
    }

    var directionLabel: String {
        switch card.direction {
        case .enToRu: "EN → RU"
        case .ruToEn: "RU → EN"
        }
    }

    var subtitle: String {
        let partOfSpeech = Self.label(for: card.partOfSpeech)
        let hint = card.direction == .ruToEn ? " · " + String(localized: "choose the English word") : ""
        guard let ipa = card.ipa, card.direction == .enToRu else { return partOfSpeech + hint }
        return "\(ipa) · \(partOfSpeech)"
    }

    var feedbackText: String? {
        guard let answer else { return nil }
        let pair = "\(card.prompt) — \(answer.result.correctAnswer)"
        switch answer.result.outcome {
        case .correct:
            return answer.result.becameLearned
                ? String(localized: "✓ Correct — word learned!")
                : String(localized: "✓ Correct")
        case .wrong:
            return "✗ \(pair)"
        case .dontKnow:
            return String(localized: "Answer: \(pair)")
        }
    }

    var feedbackIsPositive: Bool { answer?.result.outcome == .correct }

    var masteryLabel: String {
        String(localized: "Mastery \(mastery)/4")
    }

    /// Ranks 1–1000 belong to Top‑1000, 1001–2000 to Top‑2000, and so on.
    private static func tierCeiling(for rank: Int) -> Int {
        max(1, (rank + 999) / 1000) * 1000
    }

    private static func label(for partOfSpeech: PartOfSpeech) -> String {
        switch partOfSpeech {
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
