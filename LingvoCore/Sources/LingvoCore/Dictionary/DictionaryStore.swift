import Foundation
import GRDB

/// Read-only access to a dictionary that follows the bundled contract.
public struct DictionaryStore: Sendable {
    let reader: any DatabaseReader
    /// Every word that can be a quiz card: ranks up to the last `TopTier` (quiz tier
    /// in the bundled data), minus the quiz-exclusion list (names, fragments, vulgar
    /// words). Small (2k rows) and never changes at runtime, so it is loaded once;
    /// the picker and distractor rules then work without SQL.
    let quizEntries: [DictionaryEntry]
    let tierGate: TierGate
    /// Every headword by its lowercased form. The bundled file is read-only and
    /// has only a case-sensitive index; this map lets a case-insensitive lookup
    /// use that index instead of scanning all entries on each keystroke.
    private let headwordsByLowercase: [String: [String]]

    init(reader: any DatabaseReader) throws {
        self.reader = reader
        let (entries, headwords) = try reader.read { db in
            try ReadOnlyDictionaryFile.checkVersion(DictionarySchema.schemaVersion, name: "dictionary", in: db)
            let entries = try Self.fetchEntries(
                where: "e.rank <= ? AND e.headword NOT IN (SELECT headword FROM quiz_exclusions)",
                arguments: [TopTier.last.maxRank],
                in: db
            )
            return (entries, try String.fetchAll(db, sql: "SELECT headword FROM entries"))
        }
        self.quizEntries = entries.filter { $0.primaryRussian != nil }
        self.headwordsByLowercase = Dictionary(grouping: headwords) { $0.lowercased() }
        self.tierGate = TierGate(cardEntries: quizEntries)
    }

    /// Opens a dictionary file read-only, for example the one bundled with the app.
    public static func open(at url: URL) throws -> DictionaryStore {
        try DictionaryStore(reader: ReadOnlyDictionaryFile.open(at: url, name: "dictionary"))
    }

    /// Builds a private in-memory dictionary from JSON sources (tests, previews).
    public static func inMemory(fromJSON sources: [Data]) throws -> DictionaryStore {
        let source = DictionarySource.merged(try sources.map(DictionarySource.decode(json:)))
        let queue = try DatabaseQueue()
        try DictionaryBuilder.write(source, into: queue)
        return try DictionaryStore(reader: queue)
    }

    public func meta() throws -> [String: String] {
        try ReadOnlyDictionaryFile.meta(in: reader)
    }

    public func entry(headword: String) throws -> DictionaryEntry? {
        try reader.read { db in
            try Self.fetchEntries(where: "e.headword = ?", arguments: [headword], in: db).first
        }
    }

    /// Ignores case and surrounding spaces; an exact-case match wins ("US" over "us").
    func lookupEntry(_ text: String) throws -> DictionaryEntry? {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let candidates = headwordsByLowercase[query.lowercased()] else { return nil }
        let matches = try entries(headwords: candidates)
        return matches.first { $0.headword == query } ?? matches.first
    }

    /// Entries with a Russian translation equal to the text after
    /// `RussianText.normalized`, best rank first. Dictionary forms only: no morphology.
    /// The file stores that form in `norm`, so the match is one indexed query per keystroke.
    func russianLookupEntries(_ text: String, limit: Int) throws -> [DictionaryEntry] {
        try reader.read { db in
            try Self.fetchEntries(
                where: """
                    e.id IN (
                        SELECT t.entry_id FROM translations t JOIN entries m ON m.id = t.entry_id
                        WHERE t.lang = ? AND t.norm = ?
                        GROUP BY t.entry_id ORDER BY m.rank LIMIT ?
                    )
                    """,
                arguments: [Language.russian.rawValue, RussianText.normalized(text), limit],
                in: db
            )
        }
    }

    /// Ordered by rank.
    private func entries(headwords: [String]) throws -> [DictionaryEntry] {
        let placeholders = Array(repeating: "?", count: headwords.count).joined(separator: ", ")
        return try reader.read { db in
            try Self.fetchEntries(
                where: "e.headword IN (\(placeholders))", arguments: StatementArguments(headwords), in: db
            )
        }
    }

    private static func fetchEntries(
        where condition: String,
        arguments: StatementArguments,
        in db: Database
    ) throws -> [DictionaryEntry] {
        let rows = try Row.fetchAll(db, sql: """
            SELECT e.id, e.headword, e.rank, e.pos, e.ipa, e.example, e.example_ru, e.synonym_group, e.tier,
                   t.lang, t.text
            FROM entries e
            LEFT JOIN translations t ON t.entry_id = e.id
            WHERE \(condition)
            ORDER BY e.rank, t.lang, t.ord
            """, arguments: arguments)
        return try group(rows)
    }

    private static func group(_ rows: [Row]) throws -> [DictionaryEntry] {
        var entries: [DictionaryEntry] = []
        var translations: [Language: [String]] = [:]
        var current: Row?

        func flush() throws {
            guard let row = current else { return }
            entries.append(try entry(from: row, translations: translations))
        }

        for row in rows {
            if current?["id"] as Int64? != row["id"] as Int64? {
                try flush()
                current = row
                translations = [:]
            }
            if let lang: String = row["lang"], let text: String = row["text"], let language = Language(rawValue: lang) {
                translations[language, default: []].append(text)
            }
        }
        try flush()
        return entries
    }

    private static func entry(from row: Row, translations: [Language: [String]]) throws -> DictionaryEntry {
        let headword: String = row["headword"]
        guard let partOfSpeech = PartOfSpeech(rawValue: row["pos"]),
              let tier = DictionaryTier(rawValue: row["tier"]) else {
            throw LingvoCoreError.invalidDictionary("\(headword): bad pos or tier")
        }
        return DictionaryEntry(
            headword: headword,
            rank: row["rank"],
            partOfSpeech: partOfSpeech,
            ipa: row["ipa"],
            example: row["example"],
            synonymGroup: row["synonym_group"],
            tier: tier,
            translations: translations,
            russianExample: row["example_ru"]
        )
    }
}
