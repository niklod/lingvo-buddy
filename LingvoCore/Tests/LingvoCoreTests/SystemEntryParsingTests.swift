import LingvoCore
import Testing

@Suite("System dictionary text parsing: groups and limits")
struct SystemEntryParsingTests {
    @Test("several forms in parentheses before the part of speech do not hide it")
    func formsBeforePartOfSpeech() {
        let entry = SystemEntry.parse(SystemSamples.unicolor, for: "unicolor")

        #expect(entry == SystemEntry(
            ipa: "/ˈjunəˌkʌlɚ/", partOfSpeech: .adjective, definition: "of one color", example: nil
        ))
    }

    @Test("verb forms in parentheses before the part of speech do not hide it")
    func verbFormsBeforePartOfSpeech() {
        let text = "go | ɡō | (goes) (past went) verb move from one place to another: she went to the window."

        let entry = SystemEntry.parse(text, for: "go")

        #expect(entry == SystemEntry(
            ipa: "/ɡoʊ/", partOfSpeech: .verb, definition: "move from one place to another",
            example: "she went to the window."
        ))
    }
}
