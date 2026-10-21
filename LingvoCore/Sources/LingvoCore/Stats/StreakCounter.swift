import Foundation

/// Counts the streak from answer times fed newest first.
struct StreakCounter {
    private let calendar: Calendar
    private let today: Date
    private(set) var days = 0
    /// The local day of the newest answer counted so far.
    private var lastDay: Date?

    init(today: Date, calendar: Calendar) {
        self.calendar = calendar
        self.today = calendar.startOfDay(for: today)
    }

    /// Returns `false` once the streak has ended and older answers cannot change it.
    mutating func add(_ time: Date) -> Bool {
        let day = calendar.startOfDay(for: time)
        // An answer "after today" means the system clock moved back; it says nothing about the streak.
        if day > today { return true }
        guard let lastDay else {
            guard isDay(day, before: today) || day == today else { return false }
            count(day)
            return true
        }
        if day == lastDay { return true }
        guard isDay(day, before: lastDay) else { return false }
        count(day)
        return true
    }

    private mutating func count(_ day: Date) {
        days += 1
        lastDay = day
    }

    private func isDay(_ day: Date, before other: Date) -> Bool {
        calendar.date(byAdding: .day, value: -1, to: other) == day
    }
}
