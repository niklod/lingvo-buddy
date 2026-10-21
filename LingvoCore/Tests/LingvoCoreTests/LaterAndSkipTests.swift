import Foundation
import LingvoCore
import Testing

@Suite("Tutor.later and Tutor.skip")
struct LaterAndSkipTests {
    @Test("\"Later\" holds the word back for 5 minutes, then brings the same card back first")
    func laterBringsTheSameCardBackAfterFiveMinutes() throws {
        let clock = TestClock(Fixture.start)
        let tutor = try Fixture.tutor(clock: clock)
        let card = try #require(try tutor.nextCard().card)

        tutor.later(card)
        clock.advance(by: 4 * 60 + 59)
        let meanwhile = try #require(try tutor.nextCard().card)
        clock.advance(by: 1)
        let back = try #require(try tutor.nextCard().card)

        #expect(card.headword == "they")
        #expect(meanwhile.headword == "know")
        #expect(back == card)
    }

    @Test("\"Later\" does not count as an answer")
    func laterKeepsMastery() throws {
        let clock = TestClock(Fixture.start)
        let tutor = try Fixture.tutor(clock: clock)
        let first = try #require(try tutor.nextCard().card)
        _ = try tutor.answer(first, choice: first.correctIndex)
        clock.advance(by: Fixture.hour)
        let second = try #require(try tutor.nextCard().card)

        tutor.later(second)
        clock.advance(by: 5 * 60)
        let back = try #require(try tutor.nextCard().card)

        #expect(back == second)
        #expect(back.mastery == 1)
    }

    @Test("a later card waits while the quiet rules hold timed cards back")
    func laterCardRespectsQuietHours() throws {
        let clock = TestClock(Fixture.date(hour: 22, minute: 58))
        let tutor = try Fixture.tutor(clock: clock)
        let card = try #require(try tutor.nextCard(context: Fixture.timedContext()).card)
        tutor.later(card)
        clock.advance(by: 5 * 60)

        let decision = try tutor.nextCard(context: Fixture.timedContext())

        #expect(decision == .noCard(.quietHours))
    }

    @Test("\"×\" skips the word with no penalty: the next card is another word, mastery stays")
    func skipMovesOnWithoutPenalty() throws {
        let clock = TestClock(Fixture.start)
        let tutor = try Fixture.tutor(clock: clock)
        let first = try #require(try tutor.nextCard().card)
        _ = try tutor.answer(first, choice: first.correctIndex)
        clock.advance(by: Fixture.hour)
        let second = try #require(try tutor.nextCard().card)

        tutor.skip(second)
        let next = try #require(try tutor.nextCard().card)
        let afterThat = try #require(try tutor.nextCard().card)

        #expect(second.headword == "they")
        #expect(next.headword == "know")
        #expect(afterThat.headword == "they")
        #expect(afterThat.mastery == 1)
    }
}
