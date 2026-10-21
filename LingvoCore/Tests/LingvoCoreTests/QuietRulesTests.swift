import Foundation
import LingvoCore
import Testing

@Suite("Tutor.nextCard quiet rules")
struct QuietRulesTests {
    @Test("no timed card during default quiet hours, which cross midnight", arguments: [
        (23, 0), (23, 30), (0, 0), (3, 15), (8, 59),
    ])
    func quietHoursAcrossMidnight(hour: Int, minute: Int) throws {
        let tutor = try Fixture.tutor(clock: TestClock(Fixture.date(hour: hour, minute: minute)))

        let decision = try tutor.nextCard(context: Fixture.timedContext())

        #expect(decision == .noCard(.quietHours))
    }

    @Test("timed cards come outside quiet hours", arguments: [(9, 0), (12, 0), (22, 59)])
    func cardOutsideQuietHours(hour: Int, minute: Int) throws {
        let tutor = try Fixture.tutor(clock: TestClock(Fixture.date(hour: hour, minute: minute)))

        let decision = try tutor.nextCard(context: Fixture.timedContext())

        #expect(decision.card != nil)
    }

    @Test("quiet hours inside one day block only that span")
    func quietHoursWithinOneDay() throws {
        let lunch = try QuietHours(start: TimeOfDay(hour: 13, minute: 0), end: TimeOfDay(hour: 14, minute: 0))
        let clock = TestClock(Fixture.date(hour: 13, minute: 30))
        let tutor = try Fixture.tutor(clock: clock)

        let during = try tutor.nextCard(context: Fixture.timedContext(quietHours: lunch))
        clock.advance(by: 30 * 60)
        let after = try tutor.nextCard(context: Fixture.timedContext(quietHours: lunch))

        #expect(during == .noCard(.quietHours))
        #expect(after.card != nil)
    }

    @Test("a time of day outside 00:00–23:59 is rejected")
    func invalidTimeOfDay() {
        #expect(throws: LingvoCoreError.invalidTimeOfDay(hour: 24, minute: 0)) {
            try TimeOfDay(hour: 24, minute: 0)
        }
        #expect(throws: LingvoCoreError.invalidTimeOfDay(hour: 9, minute: 60)) {
            try TimeOfDay(hour: 9, minute: 60)
        }
    }

    @Test("no timed card while a Focus mode is on")
    func noCardDuringFocus() throws {
        let tutor = try Fixture.tutor(clock: TestClock(Fixture.date(hour: 12, minute: 0)))

        let decision = try tutor.nextCard(context: Fixture.timedContext(isFocusOn: true))

        #expect(decision == .noCard(.focus))
    }

    @Test("no timed card while another app is full screen")
    func noCardDuringFullScreen() throws {
        let tutor = try Fixture.tutor(clock: TestClock(Fixture.date(hour: 12, minute: 0)))

        let decision = try tutor.nextCard(context: Fixture.timedContext(isFullScreenAppFrontmost: true))

        #expect(decision == .noCard(.fullScreen))
    }

    @Test("no timed card until the pause ends, then cards come again")
    func pauseExpires() throws {
        let clock = TestClock(Fixture.date(hour: 12, minute: 0))
        let tutor = try Fixture.tutor(clock: clock)
        let until = Fixture.date(hour: 13, minute: 0)
        let context = Fixture.timedContext(pausedUntil: until)

        let paused = try tutor.nextCard(context: context)
        clock.advance(by: 60 * 60)
        let resumed = try tutor.nextCard(context: context)

        #expect(paused == .noCard(.paused(until: until)))
        #expect(resumed.card != nil)
    }

    @Test("a pause wins over the other quiet reasons")
    func pauseIsReportedFirst() throws {
        let tutor = try Fixture.tutor(clock: TestClock(Fixture.date(hour: 23, minute: 30)))
        let until = Fixture.date(hour: 23, minute: 59)

        let decision = try tutor.nextCard(context: Fixture.timedContext(
            isFocusOn: true, isFullScreenAppFrontmost: true, pausedUntil: until
        ))

        #expect(decision == .noCard(.paused(until: until)))
    }

    @Test("\"Show word now\" gives a card even when the quiet rules hold timed cards back")
    func onDemandIgnoresQuietRules() throws {
        let tutor = try Fixture.tutor(clock: TestClock(Fixture.date(hour: 23, minute: 30)))
        var context = Fixture.timedContext(
            isFocusOn: true, isFullScreenAppFrontmost: true, pausedUntil: Fixture.date(hour: 23, minute: 59)
        )
        context.trigger = .onDemand

        let decision = try tutor.nextCard(context: context)

        #expect(decision.card != nil)
    }

    @Test("pause options end one hour, three hours, or at the start of tomorrow")
    func pauseOptions() {
        let now = Fixture.date(hour: 22, minute: 30)
        let calendar = Fixture.calendar

        #expect(PauseOption.oneHour.pausedUntil(from: now, calendar: calendar) == Fixture.date(hour: 23, minute: 30))
        #expect(PauseOption.threeHours.pausedUntil(from: now, calendar: calendar)
            == Fixture.date(hour: 1, minute: 30, dayOffset: 1))
        #expect(PauseOption.untilTomorrow.pausedUntil(from: now, calendar: calendar)
            == Fixture.date(hour: 0, minute: 0, dayOffset: 1))
    }
}
