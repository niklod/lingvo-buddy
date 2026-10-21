import Foundation

public enum NoCardReason: Sendable, Equatable {
    case noWordsAvailable
    case paused(until: Date)
    case quietHours
    case focus
    case fullScreen
}

/// Environment signals the app reads from macOS and passes in, so the core
/// never calls system APIs. The default value has no quiet rules at all.
public struct CardContext: Sendable, Equatable {
    public enum Trigger: Sendable, Equatable {
        /// The interval timer asks for a card: the quiet rules apply.
        case timer
        /// The learner asked ("Show word now", ⌥⌘W): an explicit request
        /// overrides quiet hours, Focus, full screen and pause.
        case onDemand
    }

    public var trigger: Trigger
    /// `nil` turns quiet hours off.
    public var quietHours: QuietHours?
    public var isFocusOn: Bool
    public var isFullScreenAppFrontmost: Bool
    public var pausedUntil: Date?
    /// Quiet hours are local wall-clock times, so they need the learner's calendar and zone.
    public var calendar: Calendar

    public init(
        trigger: Trigger = .timer,
        quietHours: QuietHours? = nil,
        isFocusOn: Bool = false,
        isFullScreenAppFrontmost: Bool = false,
        pausedUntil: Date? = nil,
        calendar: Calendar = .current
    ) {
        self.trigger = trigger
        self.quietHours = quietHours
        self.isFocusOn = isFocusOn
        self.isFullScreenAppFrontmost = isFullScreenAppFrontmost
        self.pausedUntil = pausedUntil
        self.calendar = calendar
    }

    /// The context of a timer tick: the quiet hours come from the learner's settings.
    public static func timer(
        settings: TutorSettings,
        isFocusOn: Bool = false,
        isFullScreenAppFrontmost: Bool = false,
        pausedUntil: Date? = nil,
        calendar: Calendar = .current
    ) -> CardContext {
        CardContext(
            trigger: .timer,
            quietHours: settings.activeQuietHours,
            isFocusOn: isFocusOn,
            isFullScreenAppFrontmost: isFullScreenAppFrontmost,
            pausedUntil: pausedUntil,
            calendar: calendar
        )
    }

    /// Why a timed card must not appear at `now`, or `nil` when it may.
    /// A pause comes first: it is the learner's own, explicit choice.
    func holdReason(at now: Date) -> NoCardReason? {
        guard trigger == .timer else { return nil }
        if let pausedUntil, now < pausedUntil {
            return .paused(until: pausedUntil)
        }
        if let quietHours, quietHours.contains(now, calendar: calendar) {
            return .quietHours
        }
        if isFocusOn {
            return .focus
        }
        if isFullScreenAppFrontmost {
            return .fullScreen
        }
        return nil
    }
}
