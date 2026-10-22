import Foundation
import LingvoCore
import Testing

@Suite("A postponed card after a row action")
struct PostponedCardTests {
    private func learner() throws -> Learner {
        try Learner(settings: LearningSettings(direction: .enToRu))
    }

    /// Takes the card of `headword` and presses "Later" on it.
    private func postpone(_ headword: String, of learner: Learner) throws -> Card {
        let card = try learner.nextCard()
        try #require(card.headword == headword)
        learner.tutor.later(card)
        return card
    }

    @Test("a deleted my word does not come back after \"Later\"")
    func deletedWordDoesNotComeBack() throws {
        let learner = try learner()
        _ = try learner.tutor.addMyWord(NewMyWord(text: "zzzcustom", translation: "что-то", example: nil))
        _ = try postpone("zzzcustom", of: learner)

        try learner.tutor.deleteWord("zzzcustom")
        learner.clock.advance(by: 5 * Fixture.minute)

        #expect(try learner.nextCard().headword == "they")
    }

    @Test("a word marked learned does not come back after \"Later\" as a new word")
    func learnedWordDoesNotComeBack() throws {
        let learner = try learner()
        _ = try postpone("they", of: learner)

        try learner.tutor.markLearned("they")
        learner.clock.advance(by: 5 * Fixture.minute)

        #expect(try learner.nextCard().headword == "know")
    }

    @Test("a word with reset progress comes back with no dots")
    func resetWordComesBackFresh() throws {
        let learner = try learner()
        try learner.answerNext()
        learner.clock.advance(by: Fixture.hour)
        _ = try postpone("they", of: learner)

        try learner.tutor.resetProgress("they")
        learner.clock.advance(by: 5 * Fixture.minute)
        let card = try learner.nextCard()

        #expect(card.headword == "they")
        #expect(card.mastery == 0)
    }

    @Test("a word with an edited translation comes back with the new translation")
    func editedWordComesBackWithNewTranslation() throws {
        let learner = try learner()
        _ = try postpone("they", of: learner)

        try learner.tutor.editTranslation("they", to: "они сами")
        learner.clock.advance(by: 5 * Fixture.minute)
        let card = try learner.nextCard()

        #expect(card.headword == "they")
        #expect(card.correctAnswer == "они сами")
    }
}
