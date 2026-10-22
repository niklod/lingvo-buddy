import LingvoCore
import Testing

@Suite("The English word for the card")
struct EnglishWordInputTests {
    @Test("Cyrillic text is a problem, and the message names the trimmed text")
    func cyrillicIsAProblem() {
        #expect(EnglishWordInput.problem(in: " барьер ") == .notEnglishWord("барьер"))
        #expect(EnglishWordInput.problem(in: "барьер")?.errorDescription
            == "\"барьер\" is Russian. Type the English word for the card.")
    }

    @Test("English, mixed and empty text are not a problem here")
    func englishAndMixedPass() {
        #expect(EnglishWordInput.problem(in: "barrier") == nil)
        #expect(EnglishWordInput.problem(in: "barrier барьер") == nil)
        #expect(EnglishWordInput.problem(in: "  ") == nil)
    }

    @Test("Add refuses the text that the form check refuses, with the same error")
    func addMyWordAgreesWithTheCheck() throws {
        let learner = try QuickAddTests.learner()
        #expect(EnglishWordInput.problem(in: "сомнение") == .notEnglishWord("сомнение"))

        #expect(throws: LingvoCoreError.notEnglishWord("сомнение")) {
            try learner.tutor.addMyWord(NewMyWord(text: "сомнение", translation: "doubt", example: nil))
        }
    }
}
