import Foundation
import LingvoCore
import Testing

@Suite("Lookup and tier membership")
struct TierLookupTests {
    @Test("lookup ignores case and spaces and tells a word outside Top‑1000")
    func lookupOutsideTop1000() throws {
        let learner = try TopTierTests.learner()

        let found = try #require(try learner.tutor.lookup("  Reluctant \n"))

        #expect(found.entry.headword == "reluctant")
        #expect(found.entry.ipa == "/reluctant/")
        #expect(found.entry.partOfSpeech == .adjective)
        #expect(found.entry.translations[.russian] == ["неохотный", "нежелающий"])
        #expect(found.membership == .outside(.top1000))
    }

    @Test("a Top‑1000 word is inside Top‑1000")
    func lookupInsideTop1000() throws {
        let learner = try TopTierTests.learner()

        #expect(try learner.tutor.lookup("cat")?.membership == .inside(.top1000))
    }

    @Test("membership follows the open tier")
    func membershipFollowsOpenTier() throws {
        let learner = try TopTierTests.learner()
        let before = try learner.tutor.lookup("horse")?.membership

        try TopTierTests.learnTop1000(learner)

        #expect(before == .outside(.top1000))
        #expect(try learner.tutor.lookup("horse")?.membership == .inside(.top2000))
        #expect(try learner.tutor.lookup("cat")?.membership == .inside(.top1000))
        #expect(try learner.tutor.lookup("reluctant")?.membership == .outside(.top2000))
    }

    @Test("a quiz-excluded word is still found for quick add")
    func excludedWordIsFound() throws {
        let learner = try TopTierTests.learner()

        #expect(try learner.tutor.lookup("dude")?.entry.translations[.russian] == ["чувак"])
    }

    @Test("an exact-case headword wins over another case")
    func exactCaseWins() throws {
        let learner = try TopTierTests.learner()

        #expect(try learner.tutor.lookup("US")?.entry.headword == "US")
        #expect(try learner.tutor.lookup("us")?.entry.headword == "us")
        #expect(try learner.tutor.lookup("Us")?.entry.headword == "us")
    }

    @Test("an unknown or empty text finds nothing")
    func unknownFindsNothing() throws {
        let learner = try TopTierTests.learner()

        #expect(try learner.tutor.lookup("qwerty") == nil)
        #expect(try learner.tutor.lookup("   ") == nil)
    }
}
