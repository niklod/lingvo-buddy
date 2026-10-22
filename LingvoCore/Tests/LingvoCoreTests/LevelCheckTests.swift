import Foundation
import LingvoCore
import Testing

@Suite("Onboarding level check")
struct LevelCheckTests {
    static func wideDictionary(words: Int = 300) throws -> DictionaryStore {
        try TestDictionary.make((1...words).map { rank in
            .init("w\(rank)", rank: rank, pos: "noun", ru: ["слово\(rank)"])
        })
    }

    static func tutor(words: Int = 300, seed: UInt64 = 1) throws -> Tutor {
        try Fixture.tutor(dictionary: wideDictionary(words: words), seed: seed)
    }

    @Test("the sample has 30 different words from the easiest to the hardest part of the tier")
    func sampleSpansTier() throws {
        let sample = try Self.tutor().levelCheckSample()

        let ranks = sample.words.map(\.rank)
        #expect(sample.tier == .top1000)
        #expect(ranks.count == 30)
        #expect(Set(ranks).count == 30)
        #expect(ranks == ranks.sorted())
        #expect(ranks.first.map { $0 <= 10 } == true)
        #expect(ranks.last.map { $0 > 290 } == true)
        // One word from each tenth of the tier, so no part of it is left out.
        for band in 0..<10 {
            let low = band * 30 + 1
            #expect(ranks.contains { (low...(low + 29)).contains($0) }, "no word from ranks \(low)–\(low + 29)")
        }
    }

    @Test("another random seed samples other words of the same spread")
    func sampleIsRandomWithinBands() throws {
        let first = try Self.tutor(seed: 1).levelCheckSample().words.map(\.headword)
        let second = try Self.tutor(seed: 2).levelCheckSample().words.map(\.headword)

        #expect(first != second)
        #expect(second.count == 30)
    }

    @Test("a tier with fewer card words than the sample size offers all of them")
    func smallTierOffersEveryWord() throws {
        let sample = try Self.tutor(words: 12).levelCheckSample()

        #expect(sample.words.map(\.rank) == Array(1...12))
    }

    @Test("words the learner already has progress on are not in the sample")
    func sampleSkipsStartedWords() throws {
        let tutor = try Self.tutor(words: 40)
        let started = try #require(try tutor.nextCard().card)
        _ = try tutor.dontKnow(started)

        let sample = try tutor.levelCheckSample()

        #expect(!sample.words.map(\.headword).contains(started.headword))
        #expect(sample.words.count == 30)
    }

    static func answers(knows: (Int) -> Bool) -> [LevelCheckAnswer] {
        stride(from: 10, through: 300, by: 10).map { LevelCheckAnswer(headword: "w\($0)", knows: knows($0)) }
    }

    @Test("known words and every easier word below the level become learned")
    func knownWordsAndEasierWordsBecomeLearned() throws {
        let tutor = try Self.tutor()

        let outcome = try tutor.applyLevelCheck(Self.answers { $0 <= 150 })

        #expect(outcome == LevelCheckOutcome(learnedCount: 150, levelRank: 150))
        #expect(try tutor.tierProgress().learned == 150)
        #expect(try tutor.nextCard().card?.headword == "w151")
    }

    @Test("one unknown easy word does not lower the level, and that word is still taught")
    func singleMissDoesNotLowerLevel() throws {
        let tutor = try Self.tutor()

        let outcome = try tutor.applyLevelCheck(Self.answers { $0 <= 200 && $0 != 20 })

        #expect(outcome == LevelCheckOutcome(learnedCount: 199, levelRank: 200))
        #expect(try tutor.nextCard().card?.headword == "w20")
    }

    @Test("with many misses the level stays low, but each known word is still learned")
    func patchyAnswersKeepKnownWordsOnly() throws {
        let tutor = try Self.tutor()

        // Known: w10, w30, w50 … w290; not known: w20, w40 … w300.
        let outcome = try tutor.applyLevelCheck(Self.answers { $0 % 20 == 10 })

        #expect(outcome == LevelCheckOutcome(learnedCount: 10 + 14, levelRank: 10))
        #expect(try tutor.nextCard().card?.headword == "w11")
    }

    @Test("knowing no word changes nothing")
    func knowingNothingChangesNothing() throws {
        let tutor = try Self.tutor()

        let outcome = try tutor.applyLevelCheck(Self.answers { _ in false })

        #expect(outcome == LevelCheckOutcome(learnedCount: 0, levelRank: nil))
        #expect(try tutor.tierProgress().learned == 0)
        #expect(try tutor.nextCard().card?.headword == "w1")
    }

    @Test("the level check is not practice: no answers, no streak")
    func levelCheckLogsNoAnswers() throws {
        let tutor = try Self.tutor()

        _ = try tutor.applyLevelCheck(Self.answers { $0 <= 150 })

        let stats = try tutor.stats()
        #expect(stats.todayAnswers == 0)
        #expect(stats.streakDays == 0)
        #expect(stats.reviewsLeftToday == 0)
    }

    @Test("words known before practice come back as a review only after 60 days")
    func knownWordsReviewAfterSixtyDays() throws {
        let clock = TestClock(Fixture.start)
        let tutor = try Fixture.tutor(dictionary: Self.wideDictionary(), clock: clock)
        _ = try tutor.applyLevelCheck(Self.answers { $0 == 10 })

        clock.advance(by: 59 * Fixture.day)
        #expect(try tutor.nextCard().card?.kind == .new)

        clock.advance(by: 2 * Fixture.day)
        let review = try #require(try tutor.nextCard().card)
        #expect(review.kind == .review)
        #expect((1...10).map { "w\($0)" }.contains(review.headword))
    }

    @Test("a word the learner already practised keeps its progress")
    func practisedWordsKeepProgress() throws {
        let tutor = try Self.tutor()
        let started = try #require(try tutor.nextCard().card)
        _ = try tutor.dontKnow(started)

        let outcome = try tutor.applyLevelCheck(Self.answers { $0 <= 100 })

        #expect(started.headword == "w1")
        #expect(outcome.learnedCount == 99)
        #expect(try tutor.nextCard().card?.headword == "w1")
    }

    @Test("an answer for a word that is not a card word is refused and changes nothing")
    func unknownWordIsRefused() throws {
        let tutor = try Self.tutor()
        let answers = Self.answers { _ in true } + [LevelCheckAnswer(headword: "nope", knows: true)]

        #expect(throws: LingvoCoreError.unknownWord("nope")) {
            try tutor.applyLevelCheck(answers)
        }
        #expect(try tutor.tierProgress().learned == 0)
    }
}
