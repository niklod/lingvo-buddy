import Foundation

/// The numbers the tray menu shows. Built from the answers log and word progress.
public struct TutorStats: Sendable, Equatable {
    /// Consecutive local days with at least one answer, ending today, or
    /// yesterday while today has no answer yet.
    public let streakDays: Int
    /// Answers given today (local day), "Don't know" included.
    public let todayAnswers: Int
    public let todayCorrect: Int
    /// Correct share (0...1) of the answers of the last 7 days, "Don't know"
    /// counted as wrong; `nil` when there were no answers.
    public let accuracy: Double?
    /// Learned words whose review date is today or earlier.
    public let reviewsLeftToday: Int
    /// Learned words of the open tier (Top‑1000, then Top‑2000) out of its card words.
    public let tierProgress: TierProgress
    public let learningCount: Int
    public let myWordsCount: Int

    public init(
        streakDays: Int,
        todayAnswers: Int,
        todayCorrect: Int,
        accuracy: Double?,
        reviewsLeftToday: Int,
        tierProgress: TierProgress,
        learningCount: Int,
        myWordsCount: Int
    ) {
        self.streakDays = streakDays
        self.todayAnswers = todayAnswers
        self.todayCorrect = todayCorrect
        self.accuracy = accuracy
        self.reviewsLeftToday = reviewsLeftToday
        self.tierProgress = tierProgress
        self.learningCount = learningCount
        self.myWordsCount = myWordsCount
    }
}
