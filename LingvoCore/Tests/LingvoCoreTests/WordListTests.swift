import Foundation
import LingvoCore
import Testing

@Suite("Dictionary window lists")
struct WordListTests {
    private func learner() throws -> Learner {
        try Learner(settings: LearningSettings(direction: .enToRu))
    }

    private func add(_ text: String, _ translation: String, to learner: Learner) throws {
        _ = try learner.tutor.addMyWord(NewMyWord(text: text, translation: translation, example: nil))
    }

    @Test("a fresh learner has every Top-1000 card word in the queue, by rank")
    func freshQueue() throws {
        let page = try learner().tutor.wordList(.queue)

        #expect(page.counts == [.learning: 0, .learned: 0, .myWords: 0, .queue: 40])
        #expect(page.queueTier == .top1000)
        #expect(page.rows.prefix(3).map(\.headword) == ["they", "know", "think"])
        #expect(page.rows.first?.translation == "они")
        #expect(page.rows.first?.source == .rank(20))
        #expect(page.rows.first?.mastery == 0)
        #expect(page.rows.first?.lastAnswer == nil)
    }

    @Test("answered words leave the queue for Learning, learned words go to Learned")
    func answeredWordsMoveBetweenLists() throws {
        let learner = try learner()
        let learned = try learner.learnNextWord()
        learner.clock.advance(by: Fixture.minute)
        let (card, _) = try learner.answerNext(correctly: true)

        let page = try learner.tutor.wordList(.learning)
        let row = try #require(page.rows.first)

        #expect(page.counts == [.learning: 1, .learned: 1, .myWords: 0, .queue: 38])
        #expect(row.headword == card.headword)
        #expect(row.mastery == 1)
        #expect(row.lastAnswer == LastAnswer(outcome: .correct, at: learner.clock.now()))
        #expect(try learner.tutor.wordList(.learned).rows.map(\.headword) == [learned])
        #expect(try learner.tutor.wordList(.learned).rows.first?.mastery == 4)
    }

    @Test("my words are listed newest first with my translation; unanswered ones count as learning")
    func myWordsList() throws {
        let learner = try learner()
        try add("suggest", "советовать", to: learner)
        learner.clock.advance(by: Fixture.minute)
        try add("Kubernetes", "кубернетес", to: learner)

        let page = try learner.tutor.wordList(.myWords)

        #expect(page.rows.map(\.headword) == ["kubernetes", "suggest"])
        #expect(page.rows.map(\.translation) == ["кубернетес", "советовать"])
        #expect(page.rows.map(\.source) == [.mine, .mine])
        #expect(page.counts == [.learning: 2, .learned: 0, .myWords: 2, .queue: 39])
        #expect(try learner.tutor.wordList(.learning).rows.map(\.headword) == ["kubernetes", "suggest"])
    }

    @Test("Learning shows the latest activity first")
    func learningOrder() throws {
        let learner = try learner()
        let first = try learner.answerNext().card.headword
        learner.clock.advance(by: Fixture.minute)
        let second = try learner.answerNext(correctly: false).card.headword

        let rows = try learner.tutor.wordList(.learning).rows

        #expect(rows.map(\.headword) == [second, first])
        #expect(rows.first?.lastAnswer?.outcome == .wrong)
    }

    @Test("the queue follows the open tier")
    func queueFollowsOpenTier() throws {
        let dictionary = try TestDictionary.make([
            .init("alpha", rank: 10, pos: "noun", ru: ["альфа"]),
            .init("beta", rank: 20, pos: "noun", ru: ["бета"]),
            .lookup("gamma", rank: 1500, pos: "noun", ru: ["гамма"]),
        ])
        let clock = TestClock(Fixture.start)
        let learner = Learner(
            tutor: try Fixture.tutor(dictionary: dictionary, clock: clock, settings: LearningSettings(direction: .enToRu)),
            clock: clock
        )
        #expect(try learner.tutor.wordList(.queue).rows.map(\.headword) == ["alpha", "beta"])

        for headword in ["alpha", "beta"] {
            try learner.tutor.markLearned(headword)
        }
        let page = try learner.tutor.wordList(.queue)

        #expect(page.queueTier == .top2000)
        #expect(page.rows.map(\.headword) == ["gamma"])
    }
}
