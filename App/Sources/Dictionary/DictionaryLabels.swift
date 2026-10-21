import LingvoCore
import SwiftUI

/// Every text of the Dictionary window, built from core values.
enum DictionaryLabels {
    static func title(of list: WordList, queueTier: TopTier) -> String {
        switch list {
        case .learning: String(localized: "Learning")
        case .learned: String(localized: "Learned")
        case .myWords: String(localized: "My words")
        case .queue: String(localized: "Top‑\(String(queueTier.maxRank)) queue")
        }
    }

    static func source(_ source: CardSource) -> String {
        switch source {
        case .rank(let rank): "#\(rank)"
        case .mine: String(localized: "mine")
        }
    }

    static func lastAnswer(_ answer: LastAnswer?, now: Date) -> String {
        guard let answer else { return String(localized: "not yet") }
        return "\(outcome(answer.outcome)) · \(age(AnswerAge(of: answer.at, now: now)))"
    }

    static func lastAnswerColor(_ answer: LastAnswer?) -> Color {
        switch answer?.outcome {
        case .correct: Theme.Palette.success
        case .wrong, .dontKnow: Theme.Palette.wrongText
        case nil: Theme.Palette.textSecondary
        }
    }

    private static func outcome(_ outcome: AnswerOutcome) -> String {
        switch outcome {
        case .correct: String(localized: "correct")
        case .wrong: String(localized: "wrong")
        case .dontKnow: String(localized: "don't know")
        }
    }

    private static func age(_ age: AnswerAge) -> String {
        switch age {
        case .justNow: String(localized: "just now")
        case .minutes(let minutes): String(localized: "\(minutes) min")
        case .hours(let hours): String(localized: "\(hours) h")
        case .today: String(localized: "today")
        case .yesterday: String(localized: "yesterday")
        case .days(let days): String(localized: "\(days) days")
        case .date(let date): date.formatted(.dateTime.month(.abbreviated).day())
        }
    }

    /// The read-only "Rules" block: label and value per line.
    static func rules(_ settings: TutorSettings) -> [(label: String, value: String)] {
        [
            (String(localized: "Interval"), String(localized: "\(Int(settings.cardInterval / 60)) min")),
            (String(localized: "Learned after"), String(localized: "\(WordRow.masteryGoal) in a row")),
            (String(localized: "Reviews"), String(localized: "\(Int((settings.learning.reviewShare * 100).rounded()))% of cards")),
            (String(localized: "Quiet hours"), quietHours(settings)),
            (String(localized: "Direction"), direction(settings.learning.direction)),
        ]
    }

    private static func quietHours(_ settings: TutorSettings) -> String {
        guard let hours = settings.activeQuietHours else { return String(localized: "Off") }
        return "\(time(hours.start))–\(time(hours.end))"
    }

    private static func time(_ time: TimeOfDay) -> String {
        String(format: "%d:%02d", time.hour, time.minute)
    }

    private static func direction(_ direction: DirectionSetting) -> String {
        switch direction {
        case .enToRu: "EN → RU"
        case .ruToEn: "RU → EN"
        case .mix: String(localized: "Mix")
        }
    }

    static func emptyList(search: String) -> String {
        let text = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty
            ? String(localized: "No words here yet.")
            : String(localized: "No words match “\(text)”.")
    }
}
