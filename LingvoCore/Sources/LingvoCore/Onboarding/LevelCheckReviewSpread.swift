import Foundation

/// When the level check marks many words learned at once, one shared due day
/// would bury the learner in reviews that the review cap then drags out for
/// weeks. Instead the first reviews fill whole days from the first review
/// interval (7) to the last (60), at most ceil(count / 54) per day.
enum LevelCheckReviewSpread {
    private static let firstDay = ReviewSchedule.interval(forStage: ReviewSchedule.firstStage) / ReviewSchedule.day
    private static let lastDay = ReviewSchedule.interval(forStage: ReviewSchedule.lastStage) / ReviewSchedule.day
    private static let dayCount = Int(lastDay - firstDay) + 1

    /// Delay of the first review for the word at `index` of `count` words,
    /// in the order the reviews should come.
    static func firstReviewDelay(index: Int, of count: Int) -> TimeInterval {
        guard count > 0 else { return lastDay * ReviewSchedule.day }
        let dayOffset = index * dayCount / count
        return (firstDay + Double(dayOffset)) * ReviewSchedule.day
    }

    /// Hardest words first: the learner is least sure of them, so they are
    /// checked soonest. Rank order keeps the schedule the same on every run.
    static func reviewOrder(_ entries: [DictionaryEntry]) -> [DictionaryEntry] {
        entries.sorted { ($0.rank, $0.headword) > ($1.rank, $1.headword) }
    }
}
