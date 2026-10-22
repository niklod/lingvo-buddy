import Foundation

extension Tutor {
    /// Today and the 6 local days before it.
    static let accuracyWindowDays = 7

    /// Days are local days of `calendar`.
    public func stats(calendar: Calendar = .current) throws -> TutorStats {
        let today = calendar.startOfDay(for: clock.now())
        let windowStart = calendar.date(byAdding: .day, value: 1 - Self.accuracyWindowDays, to: today) ?? today
        let recent = try userDatabase.answers(since: windowStart)
        let todays = recent.filter { $0.answeredAt >= today }
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let words = try wordCounts(endOfToday: endOfToday)
        var streak = StreakCounter(today: today, calendar: calendar)
        try userDatabase.walkAnswerDays(before: endOfToday, calendar: calendar) { streak.add($0) }
        return TutorStats(
            streakDays: streak.days,
            todayAnswers: todays.count,
            todayCorrect: todays.correctCount,
            accuracy: recent.isEmpty ? nil : Double(recent.correctCount) / Double(recent.count),
            reviewsLeftToday: words.reviewsDue,
            tierProgress: try tierProgress(),
            learningCount: words.learning,
            myWordsCount: try userDatabase.myWordsCount()
        )
    }

    private struct WordCounts {
        var learning = 0
        var reviewsDue = 0
    }

    private func wordCounts(endOfToday: Date) throws -> WordCounts {
        var counts = WordCounts()
        for progress in try userDatabase.allProgress().values {
            switch progress.status {
            case .learning:
                counts.learning += 1
            case .learned where progress.isDue(before: endOfToday):
                counts.reviewsDue += 1
            case .learned:
                break
            }
        }
        return counts
    }
}

private extension [LoggedAnswer] {
    var correctCount: Int { filter { $0.result == .correct }.count }
}

private extension WordProgress {
    func isDue(before end: Date) -> Bool {
        dueAt.map { $0 < end } ?? true
    }
}
