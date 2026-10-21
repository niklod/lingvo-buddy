import Foundation

/// How long ago an answer was, in the steps the Dictionary window shows
/// ("12 min", "3 h", "today", "yesterday").
public enum AnswerAge: Sendable, Equatable {
    case justNow
    case minutes(Int)
    /// Only for the first few hours, also across midnight: after that "today" reads better than "9 h".
    case hours(Int)
    case today
    case yesterday
    case days(Int)
    /// A week or more ago.
    case date(Date)

    static let hoursShown = 4
    static let daysShown = 7

    public init(of time: Date, now: Date, calendar: Calendar = .current) {
        let seconds = now.timeIntervalSince(time)
        let minutes = Int(seconds / 60)
        let hours = minutes / 60
        let days = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: time), to: calendar.startOfDay(for: now)
        ).day ?? 0
        switch true {
        case minutes < 1: self = .justNow
        case hours < 1: self = .minutes(minutes)
        case hours < Self.hoursShown: self = .hours(hours)
        case days == 0: self = .today
        case days == 1: self = .yesterday
        case days < Self.daysShown: self = .days(days)
        default: self = .date(time)
        }
    }
}
