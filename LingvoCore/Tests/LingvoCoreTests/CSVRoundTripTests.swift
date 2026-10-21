import Foundation
import LingvoCore
import Testing

@Suite("CSV export and import round trip")
struct CSVRoundTripTests {
    /// A second Mac: same dictionary, empty user database, its clock at `time`.
    private func freshLearner(at time: Date = Fixture.start) throws -> Learner {
        let clock = TestClock(time)
        return Learner(tutor: try Fixture.tutor(clock: clock, settings: LearningSettings(direction: .enToRu)), clock: clock)
    }

    private func roundTrip(_ source: Learner) throws -> Learner {
        let target = try freshLearner(at: source.clock.now())
        try target.tutor.importCSV(try source.tutor.exportCSV())
        return target
    }

    @Test("my words come back with their translation and example")
    func myWordsRoundTrip() throws {
        let source = try freshLearner()
        _ = try source.tutor.addMyWord(NewMyWord(text: "eventually", translation: "со временем", example: "It will work eventually."))
        source.clock.advance(by: Fixture.minute)
        _ = try source.tutor.addMyWord(NewMyWord(text: "Kubernetes", translation: "кубернетес", example: nil))

        let target = try roundTrip(source)
        let first = try target.nextCard()
        target.tutor.skip(first)
        let second = try target.nextCard()

        #expect(try target.tutor.stats().myWordsCount == 2)
        #expect(try target.tutor.quickAddPreview("kubernetes")?.standing == .mine)
        #expect(first.headword == "eventually")
        #expect(first.source == .mine)
        #expect(first.correctAnswer == "со временем")
        #expect(first.example == "It will work eventually.")
        #expect(second.headword == "Kubernetes")
        #expect(second.correctAnswer == "кубернетес")
    }

    @Test("an own translation of a dictionary word comes back, also for a word not answered yet")
    func ownTranslationRoundTrip() throws {
        let source = try freshLearner()
        try source.tutor.editTranslation("they", to: "они сами")
        try source.tutor.editTranslation("year", to: "годик")
        try source.answerNext()

        let target = try roundTrip(source)
        let queued = try target.tutor.wordList(.queue).rows.first { $0.headword == "year" }

        #expect(try target.tutor.wordList(.learning).rows.first?.translation == "они сами")
        #expect(queued?.translation == "годик")
        #expect(queued?.source == .rank(70))
        #expect(try target.tutor.stats().myWordsCount == 0)
    }

    @Test("progress comes back: learned words, words in learning and their due times")
    func progressRoundTrip() throws {
        let source = try freshLearner()
        // Odd fractions of a second: times must survive to the millisecond.
        source.clock.advance(by: 0.1234)
        let learned = try source.learnNextWord()
        let started = try source.answerNext().card.headword
        source.clock.advance(by: Fixture.minute + 0.0567)
        let missed = try source.answerNext(correctly: false).card.headword

        let target = try roundTrip(source)
        let stats = try target.tutor.stats()

        #expect(try target.tutor.exportCSV() == source.tutor.exportCSV())
        #expect(stats.tierProgress.learned == 1)
        #expect(stats.learningCount == 2)
        #expect(try target.tutor.quickAddPreview(learned)?.standing == .learned)
        #expect(try target.tutor.quickAddPreview(started)?.standing == .learning(mastery: 1))
        #expect(try target.tutor.quickAddPreview(missed)?.standing == .learning(mastery: 0))
        #expect(try target.nextCard().headword == source.nextCard().headword)
    }

    @Test("a learned word comes back for review on the same day as before the move")
    func reviewDueTimeRoundTrip() throws {
        let source = try freshLearner()
        let learned = try source.learnNextWord()
        let target = try roundTrip(source)

        target.clock.advance(by: 7 * Fixture.day - Fixture.hour - Fixture.minute)
        let early = try target.nextCard()
        target.clock.advance(by: Fixture.minute)
        let review = try target.nextCard()

        #expect(early.headword != learned)
        #expect(review.headword == learned)
        #expect(review.kind == .review)
    }

    @Test("commas, quotes and line breaks in my text survive the file")
    func specialCharactersRoundTrip() throws {
        let source = try freshLearner()
        let example = "She said: \"Well, maybe.\"\nThen, \"no\"."
        _ = try source.tutor.addMyWord(NewMyWord(text: "reluctant", translation: "неохотный, вялый", example: example))

        let target = try roundTrip(source)
        let card = try target.nextCard()

        #expect(card.correctAnswer == "неохотный, вялый")
        #expect(card.example == example)
    }

    @Test("an import replaces the words in the file and keeps the others")
    func importMergesByWord() throws {
        let source = try freshLearner()
        _ = try source.tutor.addMyWord(NewMyWord(text: "reluctant", translation: "неохотный", example: nil))
        let target = try freshLearner()
        _ = try target.tutor.addMyWord(NewMyWord(text: "reluctant", translation: "нежелающий", example: "Old note."))
        target.clock.advance(by: Fixture.minute)
        _ = try target.tutor.addMyWord(NewMyWord(text: "Kubernetes", translation: "кубернетес", example: nil))

        let summary = try target.tutor.importCSV(try source.tutor.exportCSV())
        let card = try target.nextCard()

        #expect(summary == CSVImportSummary(words: 1, myWords: 1))
        #expect(try target.tutor.stats().myWordsCount == 2)
        #expect(card.headword == "reluctant")
        #expect(card.correctAnswer == "неохотный")
        #expect(card.example == nil)
    }

    @Test("a hand-made list of words and translations imports as my words")
    func handMadeListImports() throws {
        let target = try freshLearner()
        let csv = "Headword,Translation\nKubernetes,кубернетес\n\nreluctant,неохотный\n"

        let summary = try target.tutor.importCSV(Data(csv.utf8))

        #expect(summary == CSVImportSummary(words: 2, myWords: 2))
        #expect(try target.tutor.quickAddPreview("kubernetes")?.standing == .mine)
        #expect(try target.nextCard().correctAnswer == "кубернетес")
    }

    @Test("words learned in the onboarding level check stay at the 60-day review step")
    func levelCheckWordsRoundTrip() throws {
        let source = try freshLearner()
        let outcome = try source.tutor.applyLevelCheck([LevelCheckAnswer(headword: "know", knows: true)])
        let target = try roundTrip(source)

        target.clock.advance(by: 8 * Fixture.day)
        let afterAWeek = try target.nextCard()
        target.clock.advance(by: 53 * Fixture.day)
        let afterTwoMonths = try target.nextCard()

        #expect(outcome.learnedCount == 2)
        #expect(try target.tutor.exportCSV() == source.tutor.exportCSV())
        #expect(try target.tutor.stats().tierProgress.learned == 2)
        #expect(try target.tutor.quickAddPreview("know")?.standing == .learned)
        #expect(afterAWeek.kind == .new)
        #expect(!["they", "know"].contains(afterAWeek.headword))
        #expect(afterTwoMonths.kind == .review)
    }
}
