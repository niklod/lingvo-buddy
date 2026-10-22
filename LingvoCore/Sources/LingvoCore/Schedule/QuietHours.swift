import Foundation

/// A wall-clock time with minute precision.
public struct TimeOfDay: Sendable, Equatable, Hashable, Comparable {
    public let hour: Int
    public let minute: Int

    public init(hour: Int, minute: Int = 0) throws {
        guard (0..<24).contains(hour), (0..<60).contains(minute) else {
            throw LingvoCoreError.invalidTimeOfDay(hour: hour, minute: minute)
        }
        self.hour = hour
        self.minute = minute
    }

    private init(validHour hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    public var minutesSinceMidnight: Int { hour * 60 + minute }

    public static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        lhs.minutesSinceMidnight < rhs.minutesSinceMidnight
    }

    static func of(_ date: Date, calendar: Calendar) -> TimeOfDay {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return TimeOfDay(validHour: parts.hour ?? 0, minute: parts.minute ?? 0)
    }

    static let elevenPM = TimeOfDay(validHour: 23, minute: 0)
    static let nineAM = TimeOfDay(validHour: 9, minute: 0)
}

/// The daily span with no timed cards: `start` is inclusive, `end` exclusive.
/// When `end` is earlier than `start` the span crosses midnight.
public struct QuietHours: Sendable, Equatable, Hashable {
    public static let standard = QuietHours(start: .elevenPM, end: .nineAM)

    public let start: TimeOfDay
    public let end: TimeOfDay

    public init(start: TimeOfDay, end: TimeOfDay) {
        self.start = start
        self.end = end
    }

    /// An empty span (`start == end`) is never quiet.
    public func contains(_ date: Date, calendar: Calendar) -> Bool {
        let time = TimeOfDay.of(date, calendar: calendar)
        if start <= end {
            return start <= time && time < end
        }
        return time >= start || time < end
    }
}
