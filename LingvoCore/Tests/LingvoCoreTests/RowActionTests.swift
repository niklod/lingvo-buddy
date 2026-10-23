import Foundation
import LingvoCore
import Testing

@Suite("Dictionary window row actions")
struct RowActionTests {
    private func learner() throws -> Learner {
        try Learner(settings: LearningSettings(direction: .enToRu))
    }

    private func row(_ headword: String, in list: WordList, of learner: Learner) throws -> WordRow? {
        try learner.tutor.wordList(list).rows.first { $0.headword == headword }
    }

    @Test("Mark as learned moves a queued word to Learned and counts it in the tray, without an answer")
    func markQueuedWordLearned() throws {
        let learner = try learner()

        try learner.tutor.markLearned("they")
        let stats = try learner.tutor.stats()
        let learned = try #require(try row("they", in: .learned, of: learner))

        #expect(learned.mastery == 4)
        #expect(learned.lastAnswer == nil)
        #expect(try row("they", in: .queue, of: learner) == nil)
        #expect(stats.tierProgress.learned == 1)
        #expect(stats.todayAnswers == 0)
        #expect(try learner.nextCard().headword == "know")
    }

    @Test("a word marked learned comes back as a review after 7 days")
    func markedWordIsReviewedAfterSevenDays() throws {
        let learner = try learner()
        try learner.tutor.markLearned("they")

        learner.clock.advance(by: 7 * Fixture.day)
        let card = try learner.nextCard()

        #expect(card.headword == "they")
        #expect(card.kind == .review)
    }

    @Test("Mark as learned on a learning word keeps its last answer")
    func markLearningWordLearned() throws {
        let learner = try learner()
        let (card, _) = try learner.answerNext(correctly: false)

        try learner.tutor.markLearned(card.headword)
        let learned = try #require(try row(card.headword, in: .learned, of: learner))

        #expect(learned.lastAnswer?.outcome == .wrong)
        #expect(try learner.tutor.stats().learningCount == 0)
    }

    @Test("Reset progress sends a dictionary word back to the queue; the answers log stays")
    func resetDictionaryWord() throws {
        let learner = try learner()
        let (card, _) = try learner.answerNext()

        try learner.tutor.resetProgress(card.headword)
        let queued = try #require(try row(card.headword, in: .queue, of: learner))

        #expect(queued.mastery == 0)
        #expect(queued.lastAnswer == nil)
        #expect(!queued.canResetProgress)
        #expect(try learner.tutor.stats().learningCount == 0)
        #expect(try learner.tutor.stats().todayAnswers == 1)
    }

    @Test("Reset progress of a my word keeps it in My words, not answered")
    func resetMyWord() throws {
        let learner = try learner()
        _ = try learner.tutor.addMyWord(NewMyWord(text: "reluctant", translation: "неохотный", example: nil))
        try learner.answerNext(correctly: false)

        try learner.tutor.resetProgress("reluctant")
        let mine = try #require(try row("reluctant", in: .myWords, of: learner))

        #expect(mine.status == nil)
        #expect(mine.lastAnswer == nil)
        #expect(try learner.nextCard().headword == "reluctant")
    }

    @Test("Delete removes a my word with its progress and updates the tray count")
    func deleteMyWord() throws {
        let learner = try learner()
        _ = try learner.tutor.addMyWord(NewMyWord(text: "Kubernetes", translation: "кубернетес", example: nil))
        try learner.answerNext()

        try learner.tutor.deleteWord("kubernetes")
        let page = try learner.tutor.wordList(.myWords)

        #expect(page.rows.isEmpty)
        #expect(page.counts[.learning] == 0)
        #expect(try learner.tutor.stats().myWordsCount == 0)
        #expect(try learner.tutor.quickAddPreview("Kubernetes")?.standing == .notAdded)
    }

    @Test("Delete of a queued word moved to My words puts it back in the queue with the dictionary translation")
    func deleteMovedWord() throws {
        let learner = try learner()
        _ = try learner.tutor.addMyWord(NewMyWord(text: "suggest", translation: "советовать", example: nil))

        try learner.tutor.deleteWord("suggest")
        let queued = try #require(try row("suggest", in: .queue, of: learner))

        #expect(queued.translation == "предлагать")
        #expect(queued.source == .rank(470))
    }

    @Test("a dictionary word cannot be deleted")
    func dictionaryWordIsNotDeleted() throws {
        let learner = try learner()

        #expect(try row("they", in: .queue, of: learner)?.canDelete == false)
        #expect(throws: LingvoCoreError.notMyWord("they")) { try learner.tutor.deleteWord("they") }
    }

    @Test("Edit translation of a dictionary word shows in the table and on its card")
    func editDictionaryTranslation() throws {
        let learner = try learner()

        try learner.tutor.editTranslation("they", to: "  они сами ")
        let card = try learner.nextCard()

        #expect(try row("they", in: .queue, of: learner)?.translation == "они сами")
        #expect(card.headword == "they")
        #expect(card.correctAnswer == "они сами")
        #expect(card.source == .rank(20))
        #expect(card.kind == .new)
    }

    @Test("editing back to the dictionary translation drops the own one")
    func editBackToDictionaryTranslation() throws {
        let learner = try learner()
        try learner.tutor.editTranslation("think", to: "полагать")

        try learner.tutor.editTranslation("think", to: "думать")

        #expect(try row("think", in: .queue, of: learner)?.translation == "думать")
    }

    @Test("Edit translation of a my word changes its card")
    func editMyWordTranslation() throws {
        let learner = try learner()
        _ = try learner.tutor.addMyWord(NewMyWord(text: "reluctant", translation: "неохотный", example: nil))

        try learner.tutor.editTranslation("reluctant", to: "сопротивляющийся")

        #expect(try row("reluctant", in: .myWords, of: learner)?.translation == "сопротивляющийся")
        #expect(try learner.nextCard().correctAnswer == "сопротивляющийся")
    }

    @Test("a blank or too long translation is refused")
    func invalidTranslation() throws {
        let tutor = try Fixture.tutor()

        #expect(throws: LingvoCoreError.missingTranslation("they")) { try tutor.editTranslation("they", to: "  ") }
        #expect(throws: LingvoCoreError.tooLong(.translation, limit: 80)) {
            try tutor.editTranslation("they", to: String(repeating: "а", count: 81))
        }
    }

    @Test("actions on a word that is neither in the dictionary nor mine fail")
    func unknownWord() throws {
        let tutor = try Fixture.tutor()

        #expect(throws: LingvoCoreError.unknownWord("zzz")) { try tutor.markLearned("zzz") }
        #expect(throws: LingvoCoreError.unknownWord("zzz")) { try tutor.resetProgress("zzz") }
        #expect(throws: LingvoCoreError.unknownWord("zzz")) { try tutor.editTranslation("zzz", to: "что-то") }
    }
}
