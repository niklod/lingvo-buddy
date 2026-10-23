import LingvoCore
import SwiftUI

/// Everything the quiz card view shows. A value, so snapshot states are plain data.
struct QuizCardState: Equatable {
    struct Answer: Equatable {
        /// `nil` when the learner pressed "Don't know".
        let pickedIndex: Int?
        let result: AnswerResult
        /// The break hint counts its minutes from here; snapshots pass a fixed moment.
        var answeredAt = Date.now
    }

    let card: Card
    let answer: Answer?
    /// The learner's "Show example translation" setting, read when the card appears.
    let showsExampleTranslation: Bool
    /// The learner's "YouGlish accent" setting, read when the card appears.
    var youGlishAccent: YouGlishAccent = .all

    var isAnswered: Bool { answer != nil }

    var mastery: Int { answer?.result.mastery ?? card.mastery }

    /// Before the answer, a practice card says in the footer that no dot will come.
    var isPracticeShown: Bool { card.isPractice && !isAnswered }
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
        case .correct where answer.result.isTooSoon:
            return String(localized: "✓ Correct, but no dot")
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

    /// After a correct answer that came too soon: the break lasts until the next word is due.
    var breakHint: AttributedString? {
        guard let answer, let nextDue = answer.result.nextDueAfterTooSoon else { return nil }
        // Non-breaking spaces: a wrap inside "1 h 5 min" leaves "1" alone at the line end.
        let time = Self.breakText(nextDue.timeIntervalSince(answer.answeredAt))
            .replacingOccurrences(of: " ", with: "\u{00A0}")
        var hint = AttributedString(localized: "Too fast. Take a break — next word in \(time).")
        if let range = hint.range(of: time) {
            hint[range].inlinePresentationIntent = .stronglyEmphasized
            hint[range].swiftUI.foregroundColor = Theme.Palette.textPrimary
        }
        return hint
    }

    /// "25 min", "1 h 5 min". A word due already still reads "1 min", not "0 min".
    static func breakText(_ interval: TimeInterval) -> String {
        let minutes = max(Int((interval / 60).rounded(.up)), 1)
        let hours = minutes / 60
        guard hours > 0 else { return String(localized: "\(minutes) min") }
        let rest = minutes % 60
        return rest == 0 ? String(localized: "\(hours) h") : String(localized: "\(hours) h \(rest) min")
    }

    var russianExample: String? {
        showsExampleTranslation ? card.russianExample : nil
    }

    var youGlishURL: URL? {
        YouGlishLink.url(for: card.headword, accent: youGlishAccent)
    }

    var youGlishLabel: String {
        String(localized: "Hear “\(card.headword)” on YouGlish ↗")
    }

    var feedbackIsPositive: Bool { answer?.result.outcome == .correct }

    var masteryLabel: String {
        if isPracticeShown { return String(localized: "Practice: no new dot") }
        let label = String(localized: "Mastery \(mastery)/\(WordRow.masteryGoal)")
        return answer?.result.isTooSoon == true ? String(localized: "\(label) · unchanged") : label
    }
}
