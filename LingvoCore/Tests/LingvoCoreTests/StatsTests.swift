import Foundation
import LingvoCore
import Testing

@Suite("Stats")
struct StatsTests {
    /// 2026-10-15 10:00 Moscow time; days in these tests are Moscow days.
    private let morning = Fixture.date(hour: 10, minute: 0)

    private func learner(at start: Date? = nil, settings: LearningSettings = LearningSettings()) throws -> Learner {
        let clock = TestClock(start ?? morning)
        return Learner(tutor: try Fixture.tutor(clock: clock, settings: settings), clock: clock)
    }

    private func stats(_ learner: Learner) throws -> TutorStats {
        try learner.tutor.stats(calendar: Fixture.calendar)
    }

    @Test("today counts every answer of the local day and the correct ones")
    func todayAnswersAndCorrect() throws {
        let learner = try learner()
        try learner.answerNext(correctly: true)
        try learner.answerNext(correctly: false)
        let card = try learner.nextCard()
        _ = try learner.tutor.dontKnow(card)
        try learner.answerNext(correctly: true)

        let today = try stats(learner)

        #expect(today.todayAnswers == 4)
        #expect(today.todayCorrect == 2)
    }

    @Test("answers from yesterday do not count for today")
    func yesterdayIsNotToday() throws {
        let learner = try learner(at: Fixture.date(hour: 23, minute: 50, dayOffset: -1))
        try learner.answerNext()
        try learner.answerNext()
        learner.clock.advance(by: 20 * Fixture.minute)
        try learner.answerNext(correctly: false)

        let today = try stats(learner)

        #expect(today.todayAnswers == 1)
        #expect(today.todayCorrect == 0)
    }

    @Test("accuracy is correct answers over all answers, with Don't know as wrong")
    func accuracyCountsDontKnowAsWrong() throws {
        let learner = try learner()
        for _ in 0..<3 { try learner.answerNext(correctly: true) }
        try learner.answerNext(correctly: false)
        _ = try learner.tutor.dontKnow(try learner.nextCard())

        #expect(try stats(learner).accuracy == 0.6)
    }

    @Test("accuracy covers today and the 6 days before, not older answers")
    func accuracyWindowIsSevenDays() throws {
        let learner = try learner(at: Fixture.date(hour: 23, minute: 0, dayOffset: -7))
        try learner.answerNext(correctly: false)
        learner.clock.advance(by: 2 * Fixture.hour)
        try learner.answerNext(correctly: false)
        learner.clock.advance(by: 6 * Fixture.day)
        try learner.answerNext(correctly: true)
        try learner.answerNext(correctly: true)
        try learner.answerNext(correctly: true)

        #expect(try stats(learner).accuracy == 0.75)
    }

    /// Answers one card on each given day (offsets from 2026-10-15) at `hour`, oldest first.
    private func learnerAnswering(onDays days: [Int], hour: Int = 12) throws -> Learner {
        let first = try #require(days.first)
        let learner = try learner(at: Fixture.date(hour: hour, minute: 0, dayOffset: first))
        var current = first
        for day in days {
            learner.clock.advance(by: Double(day - current) * Fixture.day)
            current = day
            try learner.answerNext(correctly: false)
        }
        return learner
    }

    @Test("the streak counts consecutive days with at least one answer, up to today")
    func streakOfConsecutiveDays() throws {
        let learner = try learnerAnswering(onDays: [-2, -1, -1, 0])

        #expect(try stats(learner).streakDays == 3)
    }

    @Test("a day without answers ends the streak")
    func gapEndsStreak() throws {
        let learner = try learnerAnswering(onDays: [-4, -3, -1, 0])

        #expect(try stats(learner).streakDays == 2)
    }

    @Test("the streak survives until today ends without an answer")
    func streakKeptBeforeTodaysFirstAnswer() throws {
        let learner = try learnerAnswering(onDays: [-2, -1])
        learner.clock.advance(by: Fixture.day)

        #expect(try stats(learner).streakDays == 2)
        learner.clock.advance(by: Fixture.day)
        #expect(try stats(learner).streakDays == 0)
    }

    @Test("answers just before and after midnight are two streak days")
    func streakAcrossMidnight() throws {
        let learner = try learner(at: Fixture.date(hour: 23, minute: 50, dayOffset: -1))
        try learner.answerNext()
        learner.clock.advance(by: 20 * Fixture.minute)
        try learner.answerNext()

        #expect(try stats(learner).streakDays == 2)
    }

    @Test("the streak survives a daylight-saving change at midnight")
    func streakAcrossMidnightDST() throws {
        var santiago = Calendar(identifier: .gregorian)
        santiago.timeZone = try #require(TimeZone(identifier: "America/Santiago"))
        // Clocks in Santiago jump from 00:00 to 01:00 on 2026-09-06.
        let noon = try #require(santiago.date(from: DateComponents(year: 2026, month: 9, day: 5, hour: 12)))
        let learner = try learner(at: noon)
        for _ in 0..<4 {
            try learner.answerNext()
            learner.clock.advance(by: Fixture.day)
        }
        learner.clock.advance(by: -Fixture.day)

        #expect(try learner.tutor.stats(calendar: santiago).streakDays == 4)
    }

    @Test("progress counts learned Top-1000 words and words in learning")
    func learnedAndLearningCounts() throws {
        let learner = try learner()
        try learner.learnNextWord()
        try learner.answerNext()
        try learner.answerNext()

        let progress = try stats(learner)

        #expect(progress.tierProgress == TierProgress(tier: .top1000, learned: 1, total: 40))
        #expect(progress.learningCount == 2)
    }

    @Test("before the Top-2000 gate opens, the total leaves out words ranked above 1000")
    func topTotalStopsAtRank1000() throws {
        let dictionary = try TestDictionary.make([
            .init("one", rank: 1, pos: "noun", ru: ["один"]),
            .init("two", rank: 500, pos: "noun", ru: ["два"]),
            .init("three", rank: 1000, pos: "noun", ru: ["три"]),
            .init("four", rank: 1001, pos: "noun", ru: ["четыре"]),
        ])
        let tutor = try Fixture.tutor(dictionary: dictionary, clock: TestClock(morning))

        #expect(try tutor.stats(calendar: Fixture.calendar).tierProgress == TierProgress(tier: .top1000, learned: 0, total: 3))
    }

    @Test("once every Top-1000 word is learned, progress counts the Top-2000 words")
    func progressSwitchesToTop2000() throws {
        let dictionary = try TestDictionary.make([
            .init("one", rank: 1, pos: "noun", ru: ["один"]),
            .init("two", rank: 2, pos: "noun", ru: ["два"]),
            .init("three", rank: 3, pos: "noun", ru: ["три"]),
            .init("four", rank: 4, pos: "noun", ru: ["четыре"]),
            .init("fifteen", rank: 1500, pos: "noun", ru: ["пятнадцать"]),
        ])
        let clock = TestClock(morning)
        let learner = Learner(tutor: try Fixture.tutor(dictionary: dictionary, clock: clock), clock: clock)
        for _ in 0..<4 { try learner.learnNextWord() }

        #expect(try stats(learner).tierProgress == TierProgress(tier: .top2000, learned: 4, total: 5))
    }

    @Test("reviews left today count learned words due today or earlier")
    func reviewsLeftToday() throws {
        let learner = try learner()
        try learner.learnNextWord()
        #expect(try stats(learner).reviewsLeftToday == 0)

        // The review is due 7 days after the last answer, a little later on that day.
        learner.clock.advance(by: 6 * Fixture.day - 2 * Fixture.hour)
        #expect(try stats(learner).reviewsLeftToday == 0)
        learner.clock.advance(by: Fixture.day)
        #expect(try stats(learner).reviewsLeftToday == 1)
        learner.clock.advance(by: 3 * Fixture.day)
        #expect(try stats(learner).reviewsLeftToday == 1)
    }

    @Test("a fresh learner has no streak, no answers and no progress")
    func freshLearner() throws {
        let fresh = try stats(try learner())

        #expect(fresh.streakDays == 0)
        #expect(fresh.todayAnswers == 0)
        #expect(fresh.tierProgress.learned == 0)
        #expect(fresh.learningCount == 0)
        #expect(fresh.myWordsCount == 0)
        #expect(fresh.reviewsLeftToday == 0)
    }

    @Test("accuracy is unknown before the first answer")
    func noAccuracyWithoutAnswers() throws {
        #expect(try stats(try learner()).accuracy == nil)
    }
}
