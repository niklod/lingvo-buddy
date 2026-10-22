import Foundation

public struct CardScheduleSettings: Sendable, Equatable {
    public static let defaultInterval: TimeInterval = 15 * 60
    /// The range the Settings window offers (5–120 min).
    public static let intervalRange: ClosedRange<TimeInterval> = 5 * 60...120 * 60
    public static let standard = CardScheduleSettings(validInterval: defaultInterval)

    public let interval: TimeInterval
    /// An untouched card closes by itself after this time.
    public let autoCloseDelay: TimeInterval = 30
    /// How soon to look again when a quiet rule held a card back, so cards
    /// come back soon after quiet hours, Focus or full screen end.
    public let quietRetryDelay: TimeInterval = 60

    /// Any positive interval: QA runs use seconds; the Settings window keeps to `intervalRange`.
    public init(interval: TimeInterval) throws {
        guard interval.isFinite, interval > 0 else { throw LingvoCoreError.invalidInterval(interval) }
        self.interval = interval
    }

    private init(validInterval: TimeInterval) {
        interval = validInterval
    }
}

/// When the next timed card is due and what happens to a shown card.
/// A value: every event returns a new schedule, and the app keeps the latest one.
public struct CardSchedule: Sendable, Equatable {
    public enum Due: Sendable, Equatable {
        /// Ask the tutor for a timed card.
        case showCard
        /// Close the untouched card and show the dot on the icon.
        case autoClose
    }

    public private(set) var settings: CardScheduleSettings
    /// `nil` while a card is on screen: the next timer starts when it closes.
    public private(set) var nextCardAt: Date?
    public private(set) var shownCard: Card?
    /// The card that closed by itself; the icon shows a dot while it waits.
    public private(set) var waitingCard: Card?
    private var autoCloseAt: Date?

    public init(settings: CardScheduleSettings = .standard, startingAt now: Date) {
        self.settings = settings
        self.nextCardAt = now.addingTimeInterval(settings.interval)
    }

    /// The moment the app must call `due(at:)` again.
    public var nextDeadline: Date? {
        shownCard == nil ? nextCardAt : autoCloseAt
    }

    public func due(at now: Date) -> Due? {
        if shownCard != nil {
            guard let autoCloseAt, now >= autoCloseAt else { return nil }
            return .autoClose
        }
        guard let nextCardAt, now >= nextCardAt else { return nil }
        return .showCard
    }

    /// `engaged` is true when the learner asked for the card (hotkey, menu, icon click).
    public func showing(_ card: Card, at now: Date, engaged: Bool) -> CardSchedule {
        var copy = self
        copy.shownCard = card
        copy.waitingCard = nil
        copy.nextCardAt = nil
        copy.autoCloseAt = engaged ? nil : now.addingTimeInterval(settings.autoCloseDelay)
        return copy
    }

    /// The learner gave the card focus or answered it: it stays until closed.
    public func engaged() -> CardSchedule {
        var copy = self
        copy.autoCloseAt = nil
        return copy
    }

    /// "Next", "Later", "×" or Esc closed the card.
    public func closed(at now: Date) -> CardSchedule {
        var copy = self
        copy.shownCard = nil
        copy.autoCloseAt = nil
        copy.nextCardAt = now.addingTimeInterval(settings.interval)
        return copy
    }

    public func autoClosed(at now: Date) -> CardSchedule {
        var copy = closed(at: now)
        copy.waitingCard = shownCard
        return copy
    }

    /// The tutor gave no card for a timer tick.
    public func noCard(_ reason: NoCardReason, at now: Date) -> CardSchedule {
        var copy = self
        switch reason {
        case .paused(let until):
            copy.nextCardAt = max(until, now)
        case .quietHours, .focus, .fullScreen:
            copy.nextCardAt = now.addingTimeInterval(settings.quietRetryDelay)
        case .noWordsAvailable:
            copy.nextCardAt = now.addingTimeInterval(settings.interval)
        }
        return copy
    }

    /// A new interval: a running countdown restarts from `now`, so the next card
    /// follows the new pace. A pause must be applied again afterwards.
    public func withSettings(_ settings: CardScheduleSettings, at now: Date) -> CardSchedule {
        var copy = self
        copy.settings = settings
        if nextCardAt != nil {
            copy.nextCardAt = now.addingTimeInterval(settings.interval)
        }
        return copy
    }

    public func paused(until: Date) -> CardSchedule {
        guard let nextCardAt else { return self }
        var copy = self
        copy.nextCardAt = max(nextCardAt, until)
        return copy
    }

    public func resumed(at now: Date) -> CardSchedule {
        guard nextCardAt != nil else { return self }
        var copy = self
        copy.nextCardAt = now.addingTimeInterval(settings.interval)
        return copy
    }
}
