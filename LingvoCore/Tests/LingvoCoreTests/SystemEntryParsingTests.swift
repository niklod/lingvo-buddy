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
        let text = "go | gō | (goes) (past went) verb move from one place to another: she went to the window."

        let entry = SystemEntry.parse(text, for: "go")

        #expect(entry == SystemEntry(
            ipa: "/ɡoʊ/", partOfSpeech: .verb, definition: "move from one place to another",
            example: "she went to the window."
        ))
    }

    @Test("a transcription that is IPA already stays as it is", arguments: [
        ("colour | ˈkʌlə | noun the property of an object of producing different sensations on the eye.", "colour", "/ˈkʌlə/"),
        ("yes | jɛs | exclamation used to give an affirmative response.", "yes", "/jɛs/"),
        ("thought | θɔːt | noun an idea or opinion.", "thought", "/θɔːt/"),
    ])
    func ipaStaysIPA(text: String, word: String, expected: String) throws {
        let entry = try #require(SystemEntry.parse(text, for: word))

        #expect(entry.ipa == expected)
    }

    @Test("a transcription that mixes IPA and the Oxford notation gives no IPA")
    func mixedNotationGivesNone() throws {
        let entry = try #require(SystemEntry.parse("tote | tʌōt | verb carry.", for: "tote"))

        #expect(entry == SystemEntry(ipa: nil, partOfSpeech: .verb, definition: "carry", example: nil))
    }
}
