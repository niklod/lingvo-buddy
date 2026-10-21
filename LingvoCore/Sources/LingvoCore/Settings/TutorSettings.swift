import Foundation

/// Everything the learner can tune in the Settings window. Stored in the user
/// database, so it moves with the learner's progress.
///
/// Values out of range are clamped, like `LearningSettings`: a bad stored
/// value must never stop cards.
public struct TutorSettings: Sendable, Equatable {
    public static let standard = TutorSettings()

    public let learning: LearningSettings
    /// Seconds between timed cards, within `CardScheduleSettings.intervalRange`.
    public let cardInterval: TimeInterval
    /// Kept while quiet hours are off, so turning them on again restores the span.
    public let quietHours: QuietHours
    public let quietHoursEnabled: Bool

    public init(
        learning: LearningSettings = LearningSettings(),
        cardInterval: TimeInterval = CardScheduleSettings.defaultInterval,
        quietHours: QuietHours = .standard,
        quietHoursEnabled: Bool = true
    ) {
        self.learning = learning
        self.cardInterval = Self.clampedInterval(cardInterval)
        self.quietHours = quietHours
        self.quietHoursEnabled = quietHoursEnabled
    }

    /// The span the quiet rules use, or `nil` when quiet hours are off.
    public var activeQuietHours: QuietHours? {
        quietHoursEnabled ? quietHours : nil
    }

    /// A copy with the given values changed.
    public func replacing(
        learning: LearningSettings? = nil,
        cardInterval: TimeInterval? = nil,
        quietHours: QuietHours? = nil,
        quietHoursEnabled: Bool? = nil
    ) -> TutorSettings {
        TutorSettings(
            learning: learning ?? self.learning,
            cardInterval: cardInterval ?? self.cardInterval,
            quietHours: quietHours ?? self.quietHours,
            quietHoursEnabled: quietHoursEnabled ?? self.quietHoursEnabled
        )
    }

    private static func clampedInterval(_ interval: TimeInterval) -> TimeInterval {
        let range = CardScheduleSettings.intervalRange
        guard interval.isFinite else { return CardScheduleSettings.defaultInterval }
        return min(max(interval, range.lowerBound), range.upperBound)
    }
}
