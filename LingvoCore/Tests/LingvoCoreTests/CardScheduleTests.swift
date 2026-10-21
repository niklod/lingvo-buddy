import Foundation
import LingvoCore
import Testing

@Suite("CardSchedule")
struct CardScheduleTests {
    private let start = Fixture.start
    private let minute: TimeInterval = 60

    @Test("the first card is due one interval (default 15 min) after start")
    func firstCardAfterInterval() {
        let schedule = CardSchedule(startingAt: start)

        #expect(schedule.due(at: start.addingTimeInterval(15 * minute - 1)) == nil)
        #expect(schedule.due(at: start.addingTimeInterval(15 * minute)) == .showCard)
        #expect(schedule.nextDeadline == start.addingTimeInterval(15 * minute))
    }

    @Test("no new card is due while a card is on screen")
    func noCardWhileShowing() throws {
        let card = try sampleCard()
        let schedule = CardSchedule(startingAt: start)
            .showing(card, at: start.addingTimeInterval(15 * minute), engaged: true)

        #expect(schedule.shownCard == card)
        #expect(schedule.due(at: start.addingTimeInterval(120 * minute)) == nil)
        #expect(schedule.nextDeadline == nil)
    }

    @Test("the next timer starts when the card closes")
    func timerStartsOnClose() throws {
        let closedAt = start.addingTimeInterval(20 * minute)
        let schedule = CardSchedule(startingAt: start)
            .showing(try sampleCard(), at: start.addingTimeInterval(15 * minute), engaged: true)
            .closed(at: closedAt)

        #expect(schedule.shownCard == nil)
        #expect(schedule.due(at: closedAt.addingTimeInterval(15 * minute - 1)) == nil)
        #expect(schedule.due(at: closedAt.addingTimeInterval(15 * minute)) == .showCard)
    }

    @Test("an untouched card closes after 30 s, waits behind the icon dot, and the timer restarts")
    func untouchedCardAutoCloses() throws {
        let card = try sampleCard()
        let shownAt = start.addingTimeInterval(15 * minute)
        let showing = CardSchedule(startingAt: start).showing(card, at: shownAt, engaged: false)

        #expect(showing.due(at: shownAt.addingTimeInterval(29)) == nil)
        #expect(showing.due(at: shownAt.addingTimeInterval(30)) == .autoClose)

        let closedAt = shownAt.addingTimeInterval(30)
        let waiting = showing.autoClosed(at: closedAt)

        #expect(waiting.shownCard == nil)
        #expect(waiting.waitingCard == card)
        #expect(waiting.nextDeadline == closedAt.addingTimeInterval(15 * minute))
    }

    @Test("a card the learner engaged with (focus or answer) does not auto-close")
    func engagedCardStays() throws {
        let shownAt = start.addingTimeInterval(15 * minute)
        let schedule = CardSchedule(startingAt: start)
            .showing(try sampleCard(), at: shownAt, engaged: false)
            .engaged()

        #expect(schedule.due(at: shownAt.addingTimeInterval(10 * minute)) == nil)
    }

    @Test("reopening the waiting card clears the dot")
    func reopeningClearsTheDot() throws {
        let card = try sampleCard()
        let shownAt = start.addingTimeInterval(15 * minute)
        let reopened = CardSchedule(startingAt: start)
            .showing(card, at: shownAt, engaged: false)
            .autoClosed(at: shownAt.addingTimeInterval(30))
            .showing(card, at: shownAt.addingTimeInterval(5 * minute), engaged: true)

        #expect(reopened.waitingCard == nil)
        #expect(reopened.shownCard == card)
    }

    @Test("when the quiet rules hold a card back, the schedule checks again in 1 minute")
    func quietReasonRetriesSoon() {
        let tick = start.addingTimeInterval(15 * minute)
        let schedule = CardSchedule(startingAt: start).noCard(.fullScreen, at: tick)

        #expect(schedule.nextDeadline == tick.addingTimeInterval(minute))
    }

    @Test("a paused tick waits for the pause end; no words waits a full interval")
    func pauseAndEmptyQueueRetry() {
        let tick = start.addingTimeInterval(15 * minute)
        let until = tick.addingTimeInterval(60 * minute)

        let paused = CardSchedule(startingAt: start).noCard(.paused(until: until), at: tick)
        let empty = CardSchedule(startingAt: start).noCard(.noWordsAvailable, at: tick)

        #expect(paused.nextDeadline == until)
        #expect(empty.nextDeadline == tick.addingTimeInterval(15 * minute))
    }

    @Test("pausing moves the next card to the pause end; resuming restarts the interval")
    func pauseAndResume() {
        let pausedAt = start.addingTimeInterval(5 * minute)
        let until = pausedAt.addingTimeInterval(60 * minute)
        let resumedAt = pausedAt.addingTimeInterval(10 * minute)

        let paused = CardSchedule(startingAt: start).paused(until: until)
        let resumed = paused.resumed(at: resumedAt)

        #expect(paused.nextCardAt == until)
        #expect(resumed.nextCardAt == resumedAt.addingTimeInterval(15 * minute))
    }

    @Test("a custom interval is used; a non-positive one is rejected")
    func customInterval() throws {
        let settings = try CardScheduleSettings(interval: 20)

        #expect(CardSchedule(settings: settings, startingAt: start).nextCardAt == start.addingTimeInterval(20))
        #expect(throws: LingvoCoreError.invalidInterval(0)) {
            try CardScheduleSettings(interval: 0)
        }
    }

    private func sampleCard() throws -> Card {
        try #require(try Fixture.tutor().nextCard().card)
    }
}
