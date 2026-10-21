import Foundation

/// The lengths of "Pause" in the tray menu.
public enum PauseOption: String, Sendable, CaseIterable {
    case oneHour
    case threeHours
    /// Until local midnight; the morning quiet hours then take over.
    case untilTomorrow

    public func pausedUntil(from now: Date, calendar: Calendar) -> Date {
        switch self {
        case .oneHour:
            return now.addingTimeInterval(60 * 60)
        case .threeHours:
            return now.addingTimeInterval(3 * 60 * 60)
        case .untilTomorrow:
            let today = calendar.startOfDay(for: now)
            return calendar.date(byAdding: .day, value: 1, to: today) ?? now.addingTimeInterval(24 * 60 * 60)
        }
    }
}
