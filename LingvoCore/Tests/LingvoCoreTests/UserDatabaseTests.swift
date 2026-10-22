import Foundation
import LingvoCore
import Testing

@Suite("User database")
struct UserDatabaseTests {
    @Test("erase removes answers, progress, my words and own translations")
    func eraseAllRemovesEveryKindOfLearnerData() throws {
        let database = try UserDatabase.inMemory()
        let clock = TestClock(Fixture.start)
        let learner = Learner(tutor: try Fixture.tutor(userDatabase: database, clock: clock), clock: clock)
        let freshStats = try learner.tutor.stats(calendar: Fixture.calendar)
        let emptyExport = try learner.tutor.exportCSV()
        try learner.answerNext()
        _ = try learner.tutor.addMyWord(NewMyWord(text: "Kubernetes", translation: "кубернетес", example: nil))
        try learner.tutor.editTranslation("year", to: "годик")

        try database.eraseAll()

        #expect(try learner.tutor.exportCSV() == emptyExport)
        #expect(try learner.tutor.stats(calendar: Fixture.calendar) == freshStats)
    }
}
