import Foundation

/// Which way cards translate. `mix` shows mostly EN→RU with some RU→EN.
public enum DirectionSetting: String, Sendable, Codable, CaseIterable {
    case enToRu = "en_ru"
    case ruToEn = "ru_en"
    case mix
}

/// The learner-tunable learning rules (Settings window). Values out of range are
/// clamped, so a bad stored setting can never stop cards.
public struct LearningSettings: Sendable, Equatable {
    public static let defaultReviewShare = 0.2
    public static let defaultMaxActiveNewWords = 10

    public let direction: DirectionSetting
    /// The largest share of cards that may be reviews, 0...1.
    public let reviewShare: Double
    /// New words enter only while fewer words than this are in learning.
    public let maxActiveNewWords: Int

    public init(
        direction: DirectionSetting = .mix,
        reviewShare: Double = Self.defaultReviewShare,
        maxActiveNewWords: Int = Self.defaultMaxActiveNewWords
    ) {
        self.direction = direction
        self.reviewShare = reviewShare.isFinite ? min(max(reviewShare, 0), 1) : Self.defaultReviewShare
        self.maxActiveNewWords = max(maxActiveNewWords, 1)
    }
}
