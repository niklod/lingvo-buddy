import Foundation
import LingvoCore

/// A quiet rule that holds timed cards back. While one holds, the schedule only
/// retries every minute, so "Next in 1 min" would be wrong all night.
enum ScheduleHold: Equatable {
    case quietHours(until: Date)
    case focus
    case fullScreen

    /// `nil` for reasons the countdown already shows (a pause, no words).
    init?(reason: NoCardReason, quietHoursEnd: Date?) {
        switch reason {
        case .quietHours:
            guard let quietHoursEnd else { return nil }
            self = .quietHours(until: quietHoursEnd)
        case .focus: self = .focus
        case .fullScreen: self = .fullScreen
        case .paused, .noWordsAvailable: return nil
        }
    }
}
