import Foundation
import LingvoCore
import Testing

@Suite("Top‑2000 tier")
struct TopTierTests {
    /// Four Top‑1000 words; above them Top‑2000 words with full card data like the
    /// real dictionary: "large" shares the synonym group of "big", "dude" is on the
    /// quiz-exclusion list. From "fox" on the words are past rank 2000 (lookup tier).
    static func learner(direction: DirectionSetting = .mix) throws -> Learner {
        let dictionary = try TestDictionary.make([
            .init("cat", rank: 1, pos: "noun", ru: ["кошка"]),
            .init("dog", rank: 2, pos: "noun", ru: ["собака"]),
            .init("run", rank: 3, pos: "verb", ru: ["бегать"]),
            .init("big", rank: 4, pos: "adjective", ru: ["большой"]),
            .init("dude", rank: 1001, pos: "noun", ru: ["чувак"], example: "That dude is my neighbour."),
            .init("horse", rank: 1002, pos: "noun", ru: ["лошадь"], example: "The horse ran across the field."),
            .init("sing", rank: 1003, pos: "verb", ru: ["петь"]),
            .init("large", rank: 1004, pos: "adjective", ru: ["крупный"], synonymGroup: "big"),
            .lookup("fox", rank: 2001, pos: "noun", ru: ["лиса"]),
            .lookup("us", rank: 2002, pos: "pronoun", ru: ["нас"]),
            .lookup("US", rank: 2003, pos: "noun", ru: ["США"]),
            .lookup("reluctant", rank: 4870, pos: "adjective", ru: ["неохотный", "нежелающий"]),
        ], quizExclusions: ["dude"])
        let clock = TestClock(Fixture.start)
        let tutor = try Fixture.tutor(
            dictionary: dictionary, clock: clock, settings: LearningSettings(direction: direction)
        )
        return Learner(tutor: tutor, clock: clock)
    }

    /// Answers right until every card word is learned and nothing is due (at most 100 cards).
    static func answerEveryCard(_ learner: Learner) throws -> [Card] {
        var cards: [Card] = []
        while cards.count < 100, let card = try learner.tutor.nextCard().card {
            _ = try learner.tutor.answer(card, choice: card.correctIndex)
            cards.append(card)
            learner.clock.advance(by: Fixture.hour)
        }
        return cards
    }

    static func learnTop1000(_ learner: Learner) throws {
        for _ in 0..<4 {
            try learner.learnNextWord()
        }
    }

    @Test("learning every Top‑1000 word opens ranks 1001–2000")
    func learningTop1000OpensTop2000() throws {
        let learner = try Self.learner()
        try Self.learnTop1000(learner)

        let card = try learner.nextCard()

        #expect(card.headword == "horse")
        #expect(card.source == .rank(1002))
        #expect(card.source.topTier == .top2000)
        #expect(card.kind == .new)
    }

    @Test("a Top‑2000 card shows the example sentence of its word")
    func top2000CardShowsExample() throws {
        let learner = try Self.learner()
        try Self.learnTop1000(learner)

        let (card, result) = try learner.answerNext()

        #expect(card.headword == "horse")
        #expect(card.example == "The horse ran across the field.")
        #expect(Set(card.options).count == 4)
        #expect(result.outcome == .correct)
    }

    @Test("a Top‑2000 word and a Top‑1000 word of one synonym group never share a card")
    func synonymGroupSpansBothTiers() throws {
        for direction in [DirectionSetting.enToRu, .ruToEn] {
            let learner = try Self.learner(direction: direction)
            let cards = try Self.answerEveryCard(learner)

            let large = try #require(cards.first { $0.headword == "large" })
            #expect(large.source.topTier == .top2000)
            for card in cards {
                let options = Set(card.options)
                #expect(!options.isSuperset(of: ["big", "large"]), "\(card.headword): \(card.options)")
                #expect(!options.isSuperset(of: ["большой", "крупный"]), "\(card.headword): \(card.options)")
            }
        }
    }

    @Test("a Top‑1000 word still in learning keeps the tier closed")
    func unlearnedTop1000KeepsTierClosed() throws {
        let learner = try Self.learner()
        for _ in 0..<3 {
            try learner.learnNextWord()
        }
        try learner.answerNext()

        let next = try learner.nextCard()

        #expect(next.headword == "big")
        #expect(try learner.tutor.openTier() == .top1000)
    }

    @Test("progress totals switch from Top‑1000 to Top‑2000")
    func progressTotalsFollowTier() throws {
        let learner = try Self.learner()

        let before = try learner.tutor.tierProgress()
        try Self.learnTop1000(learner)
        let after = try learner.tutor.tierProgress()

        #expect(before == TierProgress(tier: .top1000, learned: 0, total: 4))
        #expect(after == TierProgress(tier: .top2000, learned: 4, total: 7))
    }

    @Test("the tier stays open when a Top‑1000 word fails its review")
    func tierStaysOpenAfterRelapse() throws {
        let learner = try Self.learner()
        try Self.learnTop1000(learner)
        try learner.answerNext()
        learner.clock.advance(by: 7 * Fixture.day)

        let (review, _) = try learner.answerNext(correctly: false)

        #expect(review.kind == .review)
        #expect(review.source.topTier == .top1000)
        #expect(try learner.tutor.openTier() == .top2000)
    }

    @Test("an excluded word and words past rank 2000 never show on a card")
    func excludedWordsNeverShow() throws {
        let learner = try Self.learner()
        let cards = try Self.answerEveryCard(learner)

        let shown = Set(cards.flatMap { [$0.headword] + $0.options })

        #expect(shown.isSuperset(of: ["horse", "sing", "large"]))
        #expect(cards.count < 100)
        #expect(shown.isDisjoint(with: ["dude", "чувак", "fox", "лиса", "reluctant", "неохотный"]))
    }

    @Test("ranks map to the tier that holds them")
    func tierOfRank() {
        #expect(TopTier.containing(rank: 1) == .top1000)
        #expect(TopTier.containing(rank: 1000) == .top1000)
        #expect(TopTier.containing(rank: 1001) == .top2000)
        #expect(TopTier.containing(rank: 2000) == .top2000)
        #expect(TopTier.containing(rank: 2001) == nil)
        #expect(CardSource.mine.topTier == nil)
    }
}
