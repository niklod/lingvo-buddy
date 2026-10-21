import Foundation
import LingvoCore
import Testing

@Suite("Answer age")
struct AnswerAgeTests {
    private let now = Fixture.date(hour: 15, minute: 0)

    private func age(minutesAgo: Double) -> AnswerAge {
        AnswerAge(of: now.addingTimeInterval(-minutesAgo * 60), now: now, calendar: Fixture.calendar)
    }

    @Test("the design's ages: minutes, then hours, then today and yesterday")
    func designAges() {
        #expect(age(minutesAgo: 0.5) == .justNow)
        #expect(age(minutesAgo: 12) == .minutes(12))
        #expect(age(minutesAgo: 40) == .minutes(40))
        #expect(age(minutesAgo: 60) == .hours(1))
        #expect(age(minutesAgo: 179) == .hours(2))
        #expect(age(minutesAgo: 180) == .hours(3))
        #expect(age(minutesAgo: 300) == .today)
        #expect(age(minutesAgo: 60 * 24) == .yesterday)
    }

    @Test("older answers count local days")
    func olderAnswers() {
        #expect(age(minutesAgo: 60 * 16) == .yesterday)
        #expect(age(minutesAgo: 60 * 24 * 2) == .days(2))
        #expect(age(minutesAgo: 60 * 24 * 6) == .days(6))
        #expect(age(minutesAgo: 60 * 24 * 7) == .date(now.addingTimeInterval(-7 * Fixture.day)))
    }

    @Test("a time after now, from a clock moved back, is just now")
    func futureIsJustNow() {
        #expect(age(minutesAgo: -10) == .justNow)
    }
}
