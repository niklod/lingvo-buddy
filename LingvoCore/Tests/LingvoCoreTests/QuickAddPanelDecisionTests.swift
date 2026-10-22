import LingvoCore
import Testing

@Suite("Details of the English word follow the latest word")
struct ChainedDetailsTests {
    private struct LookupFailed: Error {}

    private static func candidate(_ word: String) -> QuickAddCandidate {
        QuickAddCandidate(headword: word, lookup: nil, standing: .notAdded)
    }

    @Test("a typed word waits for the pause; a word asked now loads at once")
    func delayedAndImmediate() {
        let (delayed, waitStep) = ChainedDetails().wanting("scram", delayed: true)
        let (_, nowStep) = delayed.wanting("skedaddle", delayed: false)

        #expect(waitStep == .loadAfterPause("scram"))
        #expect(nowStep == .load("skedaddle"))
    }

    @Test("a word wanted after the pause, then another at once: the first word's details never show")
    func staleLoadIsDropped() {
        let (first, _) = ChainedDetails().wanting("scram", delayed: true)
        let (second, _) = first.wanting("skedaddle", delayed: false)

        let details = second
            .receiving(.success(Self.candidate("skedaddle")), for: "skedaddle")
            .receiving(.success(Self.candidate("scram")), for: "scram")

        #expect(details.details(for: "scram") == nil)
        #expect(details.details(for: "skedaddle") == Self.candidate("skedaddle"))
    }

    @Test("a lookup that throws shows no details")
    func failedLookupShowsNothing() {
        let (wanting, _) = ChainedDetails().wanting("scram", delayed: false)

        let details = wanting.receiving(.failure(LookupFailed()), for: "scram")

        #expect(details.details(for: "scram") == nil)
    }

    @Test("the same word asks once; asking it now upgrades a load that waits for the pause")
    func sameWordAsksOnce() {
        let (waiting, _) = ChainedDetails().wanting("scram", delayed: true)

        let (_, again) = waiting.wanting("scram", delayed: true)
        let (_, upgrade) = waiting.wanting("scram", delayed: false)

        #expect(again == .keep)
        #expect(upgrade == .load("scram"))
    }

    @Test("a word whose details are loaded already, or no word, cancels the pending load and loads nothing")
    func nothingToLoad() {
        let (wanting, _) = ChainedDetails().wanting("scram", delayed: false)
        let loaded = wanting.receiving(.success(Self.candidate("scram")), for: "scram")
        let (other, _) = loaded.wanting("skedaddle", delayed: true)

        let (_, back) = other.wanting("scram", delayed: false)
        let (_, none) = other.wanting(nil, delayed: false)

        #expect(back == .cancel)
        #expect(none == .cancel)
    }
}

@Suite("The machine translation fallback of quick add")
struct MachineFallbackTests {
    private static let scram = MachineTranslationRequest(text: "scram", direction: .englishToRussian)
    private static let skedaddle = MachineTranslationRequest(text: "skedaddle", direction: .englishToRussian)

    @Test("an answer to an older request is ignored")
    func staleAnswerIsIgnored() throws {
        let first = try #require(MachineFallback().requesting(Self.scram, canAsk: true))
        let second = try #require(first.requesting(Self.skedaddle, canAsk: true))

        #expect(second.receiving(.translated("убираться"), for: Self.scram) == nil)
        #expect(second.receiving(.translated("удирать"), for: Self.skedaddle)?.suggestion == .suggested("удирать"))
    }

    @Test("the same request keeps its answer; a new one waits, or shows nothing without a translator")
    func sameRequestKeepsAnswer() throws {
        let asked = try #require(MachineFallback().requesting(Self.scram, canAsk: true))
        let answered = try #require(asked.receiving(.translated("убираться"), for: Self.scram))

        #expect(answered.requesting(Self.scram, canAsk: true) == nil)
        #expect(asked.suggestion == .waiting)
        #expect(MachineFallback().requesting(Self.scram, canAsk: false)?.suggestion == MachineSuggestion.none)
    }

    @Test("a keystroke drops a waiting request, so the same word asks again after the pause")
    func keystrokeCancelsWait() throws {
        let asked = try #require(MachineFallback().requesting(Self.scram, canAsk: true))

        let cancelled = try #require(asked.cancellingWait())

        #expect(cancelled == MachineFallback())
        #expect(cancelled.requesting(Self.scram, canAsk: true)?.suggestion == .waiting)
    }

    @Test("only a missing language pack starts the download, and the same request is asked again after it")
    func downloadThenAskAgain() throws {
        let asked = try #require(MachineFallback().requesting(Self.scram, canAsk: true))
        let missing = try #require(asked.receiving(.languagePackMissing, for: Self.scram))

        let downloading = try #require(missing.downloading())

        #expect(asked.downloading() == nil)
        #expect(downloading.suggestion == .downloading)
        #expect(downloading.askingAgain(Self.scram)?.suggestion == .waiting)
        #expect(downloading.askingAgain(Self.skedaddle) == nil)
    }

    @Test("the machine is asked only when no dictionary has a translation")
    func neededRequest() throws {
        let tutor = try Fixture.tutor()

        let unknown = try tutor.quickAddPreview("Kubernetes")
        let known = try tutor.quickAddPreview("provide")
        let russian = try tutor.quickAddPreview("кубернетес")

        #expect(MachineTranslationRequest(preview: unknown, candidate: unknown?.candidates.first)
            == MachineTranslationRequest(text: "Kubernetes", direction: .englishToRussian))
        #expect(MachineTranslationRequest(preview: known, candidate: known?.candidates.first) == nil)
        #expect(MachineTranslationRequest(preview: russian, candidate: russian?.candidates.first)
            == MachineTranslationRequest(text: "кубернетес", direction: .russianToEnglish))
    }
}

@Suite("Preselected choices of quick add")
struct TranslationChoiceTests {
    @Test("a new word preselects its first dictionary translation, or the custom text without one")
    func preselection() {
        #expect(TranslationChoice.preselected(translations: ["удирать", "убегать"]) == .dictionary(0))
        #expect(TranslationChoice.preselected(translations: []) == .custom)
    }

    @Test("a suggestion is preselected only when the learner has typed nothing and picked nothing")
    func suggestionPreselection() {
        #expect(TranslationChoice.custom.afterSuggestion(typed: "  ") == .machine)
        #expect(TranslationChoice.custom.afterSuggestion(typed: "удирать") == .custom)
        #expect(TranslationChoice.dictionary(1).afterSuggestion(typed: "") == .dictionary(1))
    }

    @Test("choices survive a trailing space or another case of the same word, not a new word")
    func choicesSurviveSameWord() throws {
        let tutor = try Fixture.tutor()

        let reluctant = try #require(try tutor.quickAddPreview("reluctant"))
        let spaced = try #require(try tutor.quickAddPreview("Reluctant "))
        let other = try #require(try tutor.quickAddPreview("provide"))

        #expect(QuickAddPreview.keepsChoices(from: reluctant, to: spaced))
        #expect(!QuickAddPreview.keepsChoices(from: reluctant, to: other))
        #expect(!QuickAddPreview.keepsChoices(from: nil, to: reluctant))
    }
}
