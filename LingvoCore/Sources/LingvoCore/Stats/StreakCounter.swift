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

    /// Compares day numbers, not times: where daylight saving starts at
    /// midnight, a day begins at 01:00 and is only 23 hours long.
    private func isDay(_ day: Date, before other: Date) -> Bool {
        guard let dayNumber = calendar.ordinality(of: .day, in: .era, for: day),
              let otherNumber = calendar.ordinality(of: .day, in: .era, for: other) else { return false }
        return otherNumber - dayNumber == 1
    }
}
