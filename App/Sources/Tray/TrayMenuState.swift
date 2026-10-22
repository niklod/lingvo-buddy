import Foundation
import LingvoCore

/// The schedule facts the tray menu shows next to the stats.
struct TrayScheduleInfo: Equatable {
    /// Before the schedule exists (or after it is gone): no countdown to show.
    static let idle = TrayScheduleInfo(
        nextCardAt: nil, interval: CardScheduleSettings.defaultInterval, pausedUntil: nil, hold: nil
    )

    /// `nil` while a card is on screen: the countdown starts when it closes.
    let nextCardAt: Date?
    let interval: TimeInterval
    let pausedUntil: Date?
    let hold: ScheduleHold?
}

/// Everything the tray menu shows. A value, so snapshot states are plain data.
struct TrayMenuState: Equatable {
    let stats: TutorStats
    let schedule: TrayScheduleInfo
    let now: Date

    var isPaused: Bool { schedule.pausedUntil != nil }

    /// Kapa in the header sleeps while timed cards are held back: a pause, quiet hours, Focus, full screen.
    var kapaMood: KapaMood { isPaused || schedule.hold != nil ? .asleep : .calm }

    var streakLabel: String {
        stats.streakDays == 1
            ? String(localized: "Streak 1 day")
            : String(localized: "Streak \(stats.streakDays) days")
    }

    var topTierTitle: String {
        String(localized: "Top‑\(String(stats.tierProgress.tier.maxRank))")
    }

    var learnedLabel: String {
        String(localized: "\(String(stats.tierProgress.learned)) / \(String(stats.tierProgress.total)) learned")
    }

    /// 0...1 for the progress bar.
    var learnedFraction: Double {
        let progress = stats.tierProgress
        guard progress.total > 0 else { return 0 }
        return min(Double(progress.learned) / Double(progress.total), 1)
    }

    var accuracyValue: String {
        guard let accuracy = stats.accuracy else { return "—" }
        // Plain digits like the design ("87%"), not the locale's "87 %".
        return "\(Int((accuracy * 100).rounded()))%"
    }

    var nextCardLabel: String {
        if let until = schedule.pausedUntil {
            return String(localized: "Paused until \(until.formatted(date: .omitted, time: .shortened))")
        }
        guard let next = schedule.nextCardAt else {
            return String(localized: "Next after this card")
        }
        if let hold = schedule.hold {
            return Self.holdLabel(hold)
        }
        let minutes = max(Int((next.timeIntervalSince(now) / 60).rounded(.up)), 1)
        return String(localized: "Next in \(minutes) min")
    }

    var intervalLabel: String {
        String(localized: "every \(Self.durationText(schedule.interval))")
    }

    var pauseLabel: String {
        isPaused ? String(localized: "Resume") : String(localized: "Pause for 1 hour")
    }

    var todayLabel: String {
        let answers = stats.todayAnswers == 1
            ? String(localized: "1 answer")
            : String(localized: "\(stats.todayAnswers) answers")
        return String(localized: "Today: \(answers) · \(stats.todayCorrect) correct")
    }

    var reviewsLabel: String {
        String(localized: "Reviews left today: \(stats.reviewsLeftToday)")
    }

    private static func holdLabel(_ hold: ScheduleHold) -> String {
        switch hold {
        case .quietHours(let until):
            String(localized: "Quiet hours until \(until.formatted(date: .omitted, time: .shortened))")
        case .focus:
            String(localized: "On hold while Focus is on")
        case .fullScreen:
            String(localized: "On hold while an app is full screen")
        }
    }

    /// Whole minutes for the Settings range; QA runs use seconds.
    static func durationText(_ interval: TimeInterval) -> String {
        let seconds = Int(interval.rounded())
        guard seconds % 60 == 0 else { return String(localized: "\(seconds) s") }
        return String(localized: "\(seconds / 60) min")
    }
}
