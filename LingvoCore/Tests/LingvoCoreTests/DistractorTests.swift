import Foundation
import LingvoCore
import Testing

@Suite("Distractors")
struct DistractorTests {
    /// "suggest" comes first; nouns sit nearer in rank than most verbs.
    private static let suggestFirst: [TestDictionary.Entry] = [
        .init("suggest", rank: 1, pos: "verb", ru: ["предлагать", "советовать"]),
        .init("idea", rank: 2, pos: "noun", ru: ["идея"]),
        .init("propose", rank: 3, pos: "verb", ru: ["выдвигать"], synonymGroup: "suggest"),
        .init("plan", rank: 4, pos: "noun", ru: ["план"]),
        .init("offer", rank: 5, pos: "verb", ru: ["предлагать"]),
        .init("advise", rank: 6, pos: "verb", ru: ["рекомендовать", "советовать"]),
        .init("way", rank: 7, pos: "noun", ru: ["путь"]),
        .init("explain", rank: 10, pos: "verb", ru: ["объяснять"]),
        .init("refuse", rank: 11, pos: "verb", ru: ["отказывать"]),
        .init("require", rank: 12, pos: "verb", ru: ["требовать"]),
        .init("know", rank: 13, pos: "verb", ru: ["знать"]),
        .init("think", rank: 14, pos: "verb", ru: ["думать"]),
        .init("allow", rank: 15, pos: "verb", ru: ["позволять"]),
        .init("forget", rank: 40, pos: "verb", ru: ["забывать"]),
        .init("remember", rank: 41, pos: "verb", ru: ["помнить"]),
    ]
    private static let nearestAllowedVerbs: Set = ["explain", "refuse", "require", "know", "think", "allow"]
    private static let russianOfVerbs: [String: String] = [
        "explain": "объяснять", "refuse": "отказывать", "require": "требовать",
        "know": "знать", "think": "думать", "allow": "позволять",
    ]

    @Test("RU → EN options are nearby words of the same part of speech, never synonyms or shared translations")
    func ruToEnDistractors() throws {
        for seed in 1...20 {
            let card = try firstCard(direction: .ruToEn, seed: UInt64(seed))
            let distractors = Set(card.options).subtracting([card.correctAnswer])

            #expect(card.prompt == "предлагать")
            #expect(card.correctAnswer == "suggest")
            #expect(distractors.count == 3)
            #expect(distractors.isSubset(of: Self.nearestAllowedVerbs), "seed \(seed): \(card.options)")
        }
    }

    @Test("EN → RU options are translations of nearby same-POS words, never the answer's meanings")
    func enToRuDistractors() throws {
        let allowed = Set(Self.nearestAllowedVerbs.compactMap { Self.russianOfVerbs[$0] })
        for seed in 1...20 {
            let card = try firstCard(direction: .enToRu, seed: UInt64(seed))
            let distractors = Set(card.options).subtracting([card.correctAnswer])

            #expect(card.correctAnswer == "предлагать")
            #expect(distractors.count == 3)
            #expect(distractors.isSubset(of: allowed), "seed \(seed): \(card.options)")
        }
    }

    @Test("distractors vary between cards of the same word")
    func distractorsVary() throws {
        let optionSets = try (1...20).map { seed in Set(try firstCard(direction: .ruToEn, seed: UInt64(seed)).options) }

        #expect(Set(optionSets).count > 1)
    }

    @Test("a part of speech with too few words is filled with the nearest other words")
    func fewWordsOfThePartOfSpeech() throws {
        let card = try Learner().nextCard()

        #expect(card.partOfSpeech == .pronoun)
        #expect(Set(card.options).count == 4)
    }

    @Test("a quiz-tier card takes options only from quiz-tier words, which have the synonym check data")
    func quizCardSkipsLookupWords() throws {
        let entries: [TestDictionary.Entry] = [
            .init("begin", rank: 1, pos: "verb", ru: ["начинать"]),
            .lookup("commence", rank: 2, pos: "verb", ru: ["приступать"]),
            .lookup("launch", rank: 3, pos: "verb", ru: ["запускать"]),
            .lookup("initiate", rank: 4, pos: "verb", ru: ["затевать"]),
            .init("eat", rank: 50, pos: "verb", ru: ["есть"]),
            .init("sleep", rank: 60, pos: "verb", ru: ["спать"]),
            .init("run", rank: 70, pos: "verb", ru: ["бежать"]),
        ]
        for seed in 1...5 {
            let card = try firstCard(direction: .ruToEn, seed: UInt64(seed), entries: entries)

            #expect(card.headword == "begin")
            #expect(Set(card.options) == ["begin", "eat", "sleep", "run"], "seed \(seed): \(card.options)")
        }
    }

    private func firstCard(
        direction: DirectionSetting,
        seed: UInt64,
        entries: [TestDictionary.Entry] = suggestFirst
    ) throws -> Card {
        let tutor = try Fixture.tutor(
            dictionary: TestDictionary.make(entries),
            seed: seed,
            settings: LearningSettings(direction: direction)
        )
        return try #require(try tutor.nextCard().card)
    }
}
