import Foundation

/// Why a CSV file cannot be imported. Import is all or nothing: after any of
/// these, the learner's data is as it was before.
public enum CSVImportError: Error, Equatable, LocalizedError {
    case fileTooLarge(limitBytes: Int)
    case tooManyRows(limit: Int)
    /// Excel in many locales saves CSV with ";": the header then reads as one unknown column.
    case semicolonSeparated
    case notUTF8
    case empty
    case unterminatedQuote(line: Int)
    case misplacedQuote(line: Int)
    case missingColumns([String])
    case unknownColumns([String])
    case duplicateColumns([String])
    case wrongFieldCount(line: Int, expected: Int, found: Int)
    case missingValue(line: Int, column: String)
    case invalidValue(line: Int, column: String, value: String, expected: String)
    case tooLong(line: Int, column: String, limit: Int)
    /// A translation cell with separators only: dropping it silently would lose the row's translation.
    case noTranslation(line: Int, column: String)
    case duplicateWord(line: Int, headword: String)
    /// Progress or an own translation for a word that is neither in the dictionary nor given a translation.
    case unknownWord(line: Int, headword: String)
    /// A progress column has a value, but the word has no status.
    case progressWithoutStatus(line: Int, column: String)
    /// No translation (my word), status (progress) or own translation.
    case nothingToImport(line: Int, headword: String)

    public var errorDescription: String? {
        switch self {
        case .fileTooLarge(let limit):
            "The file is too large for a LingvoBuddy export (more than \(limit / 1_000_000) MB)."
        case .tooManyRows(let limit):
            "The file has more than \(limit) words. Split it into smaller files."
        case .semicolonSeparated:
            "The values are separated by \";\". Save the file as CSV with commas and try again."
        case .notUTF8:
            "The file is not UTF-8 text. Save it as \"CSV UTF-8\" and try again."
        case .empty:
            "The file is empty."
        case .unterminatedQuote(let line):
            "Line \(line): a quoted value has no closing quote."
        case .misplacedQuote(let line):
            "Line \(line): a quote is in the wrong place. Put the whole value in quotes and double the quotes inside it."
        case .missingColumns(let columns):
            "The file is not a LingvoBuddy export: these columns are missing: \(columns.joined(separator: ", "))."
        case .unknownColumns(let columns):
            "The file has columns LingvoBuddy does not know: \(columns.joined(separator: ", "))."
        case .duplicateColumns(let columns):
            "The header has these columns more than once: \(columns.joined(separator: ", "))."
        case .wrongFieldCount(let line, let expected, let found):
            "Line \(line): \(found) values, but the header has \(expected) columns."
        case .missingValue(let line, let column):
            "Line \(line): \"\(column)\" is empty."
        case .invalidValue(let line, let column, let value, let expected):
            "Line \(line): \"\(value)\" is not a valid \(column). Expected: \(expected)."
        case .tooLong(let line, let column, let limit):
            "Line \(line): \"\(column)\" is too long: at most \(limit) characters."
        case .noTranslation(let line, let column):
            "Line \(line): \"\(column)\" has no translation in the cell, only separators."
        case .duplicateWord(let line, let headword):
            "Line \(line): \"\(headword)\" is already on an earlier line."
        case .unknownWord(let line, let headword):
            "Line \(line): \"\(headword)\" is not in the dictionary. Give it a translation to import it as one of your words."
        case .progressWithoutStatus(let line, let column):
            "Line \(line): \"\(column)\" has a value, but \"status\" is empty."
        case .nothingToImport(let line, let headword):
            "Line \(line): \"\(headword)\" has no translation, status or own translation."
        }
    }
}
