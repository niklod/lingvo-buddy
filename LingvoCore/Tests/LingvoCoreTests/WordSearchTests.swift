import Foundation
import LingvoCore
import Testing

@Suite("Dictionary window search")
struct WordSearchTests {
    @Test("search finds a word by part of the headword, ignoring case")
    func searchByWord() throws {
        let tutor = try Fixture.tutor()

        let page = try tutor.wordList(.queue, search: "  THE ")

        #expect(page.rows.map(\.headword) == ["they", "whether", "therefore"])
        #expect(page.counts[.queue] == 3)
    }

    @Test("search finds a word by any of its translations")
    func searchByTranslation() throws {
        let tutor = try Fixture.tutor()

        #expect(try tutor.wordList(.queue, search: "Считать").rows.map(\.headword) == ["think"])
        #expect(try tutor.wordList(.queue, search: "в итоге").rows.isEmpty)
        #expect(try tutor.wordList(.queue, search: "предлаг").rows.map(\.headword) == ["offer", "suggest", "propose"])
    }

    @Test("counts show the matches of every list, so the sidebar points to them")
    func countsFollowSearch() throws {
        let learner = try Learner(settings: LearningSettings(direction: .enToRu))
        _ = try learner.tutor.addMyWord(NewMyWord(text: "reluctant", translation: "неохотный", example: nil))
        try learner.tutor.markLearned("suggest")

        let page = try learner.tutor.wordList(.learning, search: "о")

        #expect(page.counts[.learned] == 1)
        #expect(page.counts[.myWords] == 1)
        #expect(page.rows.map(\.headword) == ["reluctant"])
        #expect(try learner.tutor.wordList(.learning, search: "nothing like it").counts.values.allSatisfy { $0 == 0 })
    }

    @Test("an own translation is found too")
    func searchByOwnTranslation() throws {
        let tutor = try Fixture.tutor()
        try tutor.editTranslation("year", to: "годик")

        #expect(try tutor.wordList(.queue, search: "годик").rows.map(\.headword) == ["year"])
    }
}
