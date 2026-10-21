import Foundation
import LingvoCore
import Testing

@Suite("Tutor settings")
struct SettingsTests {
    @Test("a new learner gets the spec defaults")
    func specDefaults() throws {
        let tutor = try Fixture.tutor()

        let settings = tutor.settings

        #expect(settings.cardInterval == 15 * Fixture.minute)
        #expect(settings.quietHoursEnabled)
        #expect(settings.quietHours == .standard)
        #expect(settings.learning.direction == .mix)
        #expect(settings.learning.reviewShare == 0.2)
        #expect(settings.learning.maxActiveNewWords == 10)
    }

    @Test("changed settings are still there after the app restarts")
    func settingsPersist() throws {
        let url = Fixture.temporaryDatabaseURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let lunch = try QuietHours(start: TimeOfDay(hour: 13, minute: 0), end: TimeOfDay(hour: 14, minute: 30))
        let changed = TutorSettings(
            learning: LearningSettings(direction: .ruToEn, reviewShare: 0.3, maxActiveNewWords: 4),
            cardInterval: 45 * Fixture.minute,
            quietHours: lunch,
            quietHoursEnabled: false
        )
        try Fixture.tutor(userDatabase: UserDatabase.open(at: url)).updateSettings(changed)

        let restarted = try Fixture.tutor(userDatabase: UserDatabase.open(at: url))

        #expect(restarted.settings == changed)
    }

    @Test("an interval outside 5–120 min is clamped into the range")
    func intervalIsClamped() {
        #expect(TutorSettings(cardInterval: 60).cardInterval == 5 * Fixture.minute)
        #expect(TutorSettings(cardInterval: 10 * Fixture.hour).cardInterval == 120 * Fixture.minute)
    }

    @Test("a lower max of active new words holds new words back from the next card on")
    func maxActiveDrivesPicker() throws {
        let learner = try Learner()
        let started = try (0..<3).map { _ in try learner.answerNext(correctly: false).card.headword }

        try learner.tutor.updateSettings(
            learner.tutor.settings.replacing(learning: LearningSettings(maxActiveNewWords: 3))
        )
        let next = try (0..<5).map { _ in try learner.answerNext(correctly: false).card.headword }

        #expect(Set(next).isSubset(of: Set(started)))
    }

    @Test("a new direction applies to the next card")
    func directionDrivesNextCard() throws {
        let tutor = try Fixture.tutor(settings: LearningSettings(direction: .enToRu))
        #expect(try tutor.nextCard().card?.direction == .enToRu)

        try tutor.updateSettings(tutor.settings.replacing(learning: LearningSettings(direction: .ruToEn)))

        #expect(try tutor.nextCard().card?.direction == .ruToEn)
    }

    @Test("the timer context follows the quiet hours in the settings")
    func quietHoursFromSettings() throws {
        let lunch = try QuietHours(start: TimeOfDay(hour: 13, minute: 0), end: TimeOfDay(hour: 14, minute: 0))
        let tutor = try Fixture.tutor(clock: TestClock(Fixture.date(hour: 13, minute: 30)))

        try tutor.updateSettings(tutor.settings.replacing(quietHours: lunch))
        let during = try tutor.nextCard(context: .timer(settings: tutor.settings, calendar: Fixture.calendar))
        try tutor.updateSettings(tutor.settings.replacing(quietHoursEnabled: false))
        let switchedOff = try tutor.nextCard(context: .timer(settings: tutor.settings, calendar: Fixture.calendar))

        #expect(during == .noCard(.quietHours))
        #expect(switchedOff.card != nil)
    }
}
