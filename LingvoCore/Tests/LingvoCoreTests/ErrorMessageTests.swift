import Foundation
import LingvoCore
import Testing

/// The app shows these texts to the learner as they are.
@Suite("Error messages")
struct ErrorMessageTests {
    struct Message: Sendable, CustomTestStringConvertible {
        let error: any LocalizedError & Sendable
        let text: String

        init(_ error: any LocalizedError & Sendable, _ text: String) {
            self.error = error
            self.text = text
        }

        var testDescription: String { text }
    }

    static let coreMessages: [Message] = [
        Message(LingvoCoreError.invalidDictionary("no entries"), "The dictionary is not valid: no entries"),
        Message(LingvoCoreError.unknownWord("zzz"), "The word \"zzz\" is not in the dictionary."),
        Message(LingvoCoreError.invalidChoice(4), "Option 4 does not exist on this card."),
        Message(LingvoCoreError.invalidTimeOfDay(hour: 25, minute: 0), "25:0 is not a valid time of day."),
        Message(LingvoCoreError.invalidInterval(-5), "A card interval of -5.0 s is not valid; it must be positive."),
        Message(LingvoCoreError.emptyWord, "Type a word to add."),
        Message(LingvoCoreError.missingTranslation("reluctant"), "Type a translation for \"reluctant\"."),
        Message(LingvoCoreError.tooLong(.example, limit: 300), "The example is too long: at most 300 characters."),
        Message(
            LingvoCoreError.notMyWord("they"),
            "\"they\" is a dictionary word, not one of your words: it cannot be deleted."
        ),
    ]

    static let csvMessages: [Message] = [
        Message(
            CSVImportError.fileTooLarge(limitBytes: 10_000_000),
            "The file is too large for a LingvoBuddy export (more than 10 MB)."
        ),
        Message(CSVImportError.tooManyRows(limit: 20_000), "The file has more than 20000 words. Split it into smaller files."),
        Message(
            CSVImportError.semicolonSeparated,
            "The values are separated by \";\". Save the file as CSV with commas and try again."
        ),
        Message(CSVImportError.notUTF8, "The file is not UTF-8 text. Save it as \"CSV UTF-8\" and try again."),
        Message(CSVImportError.empty, "The file is empty."),
        Message(CSVImportError.unterminatedQuote(line: 3), "Line 3: a quoted value has no closing quote."),
        Message(
            CSVImportError.misplacedQuote(line: 3),
            "Line 3: a quote is in the wrong place. Put the whole value in quotes and double the quotes inside it."
        ),
        Message(
            CSVImportError.missingColumns(["headword"]),
            "The file is not a LingvoBuddy export: these columns are missing: headword."
        ),
        Message(
            CSVImportError.unknownColumns(["name", "age"]),
            "The file has columns LingvoBuddy does not know: name, age."
        ),
        Message(
            CSVImportError.duplicateColumns(["status"]),
            "The header has these columns more than once: status."
        ),
        Message(
            CSVImportError.wrongFieldCount(line: 3, expected: 5, found: 6),
            "Line 3: 6 values, but the header has 5 columns."
        ),
        Message(CSVImportError.missingValue(line: 3, column: "headword"), "Line 3: \"headword\" is empty."),
        Message(
            CSVImportError.tooLong(line: 3, column: "example", limit: 300),
            "Line 3: \"example\" is too long: at most 300 characters."
        ),
        Message(
            CSVImportError.duplicateWord(line: 3, headword: "Eventually"),
            "Line 3: \"Eventually\" is already on an earlier line."
        ),
        Message(
            CSVImportError.unknownWord(line: 3, headword: "zzzz"),
            "Line 3: \"zzzz\" is not in the dictionary. Give it a translation to import it as one of your words."
        ),
        Message(
            CSVImportError.progressWithoutStatus(line: 3, column: "mastery"),
            "Line 3: \"mastery\" has a value, but \"status\" is empty."
        ),
        Message(
            CSVImportError.nothingToImport(line: 3, headword: "reluctant"),
            "Line 3: \"reluctant\" has no translation, status or own translation."
        ),
    ]

    @Test("core errors read as the learner should see them", arguments: coreMessages)
    func coreErrorText(_ message: Message) {
        #expect(message.error.errorDescription == message.text)
    }

    @Test("CSV import errors read as the learner should see them", arguments: csvMessages)
    func csvErrorText(_ message: Message) {
        #expect(message.error.errorDescription == message.text)
    }

    @Test("out-of-range learning settings are clamped, so a bad value never stops cards")
    func learningSettingsAreClamped() {
        #expect(LearningSettings(reviewShare: .nan).reviewShare == 0.2)
        #expect(LearningSettings(reviewShare: -0.5).reviewShare == 0)
        #expect(LearningSettings(reviewShare: 1.5).reviewShare == 1)
        #expect(LearningSettings(maxActiveNewWords: 0).maxActiveNewWords == 1)
    }
}
