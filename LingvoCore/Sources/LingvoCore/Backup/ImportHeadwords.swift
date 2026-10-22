import Foundation

/// Gives each CSV line the headword it is stored under, with the quick-add case
/// rules: spreadsheets often capitalise the first cell, and "They" must land on
/// the dictionary word "they", not become a second word that nothing reads.
struct ImportHeadwords {
    /// Both ignore case and return the stored spelling.
    private let dictionarySpelling: (String) throws -> String?
    private let myWordSpelling: (String) throws -> String?
    private var fileSpellings: [String: String] = [:]
    private var seen: Set<String> = []

    init(
        dictionarySpelling: @escaping (String) throws -> String?,
        myWordSpelling: @escaping (String) throws -> String?
    ) {
        self.dictionarySpelling = dictionarySpelling
        self.myWordSpelling = myWordSpelling
    }

    /// A word the dictionary lacks imports only with its translation: progress
    /// or an own translation alone would be rows that no list shows and no row
    /// action can remove.
    mutating func resolve(_ typed: String, line: Int, isMyWord: Bool) throws -> String {
        let headword: String
        if let entry = try dictionarySpelling(typed) {
            headword = entry
        } else if isMyWord {
            headword = try myWordSpelling(typed) ?? fileSpellings[typed.lowercased(), default: typed]
            fileSpellings[typed.lowercased()] = headword
        } else {
            throw CSVImportError.unknownWord(line: line, headword: typed)
        }
        guard seen.insert(headword).inserted else {
            throw CSVImportError.duplicateWord(line: line, headword: typed)
        }
        return headword
    }
}
