import Foundation
import LingvoCore
import Testing

@Suite("First-run onboarding")
struct OnboardingTests {
    @Test("a new learner gets onboarding")
    func newLearnerNeedsOnboarding() throws {
        #expect(try Fixture.tutor().needsOnboarding())
    }

    @Test("once finished or skipped, onboarding does not come back after a restart")
    func finishedOnboardingStaysFinished() throws {
        let url = Fixture.temporaryDatabaseURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try Fixture.tutor(userDatabase: UserDatabase.open(at: url)).completeOnboarding()

        let restarted = try Fixture.tutor(userDatabase: UserDatabase.open(at: url))

        #expect(try !restarted.needsOnboarding())
    }

    @Test("a learner who practised before onboarding existed does not get it")
    func practisedLearnerSkipsOnboarding() throws {
        let learner = try Learner()
        try learner.answerNext()

        #expect(try !learner.tutor.needsOnboarding())
    }

    @Test("finishing onboarding keeps the settings chosen in it")
    func completingKeepsSettings() throws {
        let tutor = try Fixture.tutor()
        try tutor.updateSettings(tutor.settings.replacing(cardInterval: 30 * Fixture.minute))

        try tutor.completeOnboarding()

        #expect(tutor.settings.cardInterval == 30 * Fixture.minute)
    }
}
