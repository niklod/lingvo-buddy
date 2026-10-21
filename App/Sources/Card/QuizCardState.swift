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
            // Ranks past Top‑2000 never become cards; the rank itself is a safe fallback.
            String(localized: "Top‑\(String(card.source.topTier?.maxRank ?? rank)) · #\(String(rank))")
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
        let partOfSpeech = card.partOfSpeech.label
        let hint = card.direction == .ruToEn ? " · " + String(localized: "choose the English word") : ""
        guard let ipa = card.ipa, card.direction == .enToRu else { return partOfSpeech + hint }
        return "\(ipa) · \(partOfSpeech)"
    }

    var feedbackText: String? {
        guard let answer else { return nil }
        let pair = "\(card.prompt) — \(answer.result.correctAnswer)"
        switch answer.result.outcome {
        case .correct:
            // A passed review also confirms the word as learned (design state q5).
            return answer.result.isLearned
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
}
