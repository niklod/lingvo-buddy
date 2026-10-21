import Foundation

extension Tutor {
    /// Today and the 6 local days before it.
    static let accuracyWindowDays = 7
    /// The progress card tracks the most frequent words up to this rank.
    public static let topTierRank = 1000

    /// Days are local days of `calendar`.
    public func stats(calendar: Calendar = .current) throws -> TutorStats {
        let today = calendar.startOfDay(for: clock.now())
        let windowStart = calendar.date(byAdding: .day, value: 1 - Self.accuracyWindowDays, to: today) ?? today
        let recent = try userDatabase.answers(since: windowStart)
        let todays = recent.filter { $0.answeredAt >= today }
        let words = try wordCounts(endOfToday: calendar.date(byAdding: .day, value: 1, to: today) ?? today)
        var streak = StreakCounter(today: today, calendar: calendar)
        try userDatabase.walkAnswerTimes { streak.add($0) }
        return TutorStats(
            streakDays: streak.days,
            todayAnswers: todays.count,
            todayCorrect: todays.correctCount,
            accuracy: recent.isEmpty ? nil : Double(recent.correctCount) / Double(recent.count),
            reviewsLeftToday: words.reviewsDue,
            learnedTopWords: words.learnedTop,
            topWordsTotal: words.topTotal,
            learningCount: words.learning,
            // Quick add (#19) brings the learner's own words; until then there are none.
            myWordsCount: 0
        )
    }

    private struct WordCounts {
        var learnedTop = 0
        var topTotal = 0
        var learning = 0
        var reviewsDue = 0
    }

    private func wordCounts(endOfToday: Date) throws -> WordCounts {
        let topWords = Set(dictionary.quizEntries.filter { $0.rank <= Self.topTierRank }.map(\.headword))
        var counts = WordCounts(topTotal: topWords.count)
        for progress in try userDatabase.allProgress().values {
            switch progress.status {
            case .learning:
                counts.learning += 1
            case .learned:
                if topWords.contains(progress.headword) { counts.learnedTop += 1 }
                if progress.isDue(before: endOfToday) { counts.reviewsDue += 1 }
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
