import Foundation
import GRDB

/// Read-only access to a dictionary that follows the bundled contract.
public struct DictionaryStore: Sendable {
    private let reader: any DatabaseReader
    /// Every word that can be a quiz card: ranks up to the last `TopTier`, quiz and
    /// lookup tier alike, minus the quiz-exclusion list (names, fragments, vulgar
    /// words). Small (2k rows) and never changes at runtime, so it is loaded once;
    /// the picker and distractor rules then work without SQL.
    let quizEntries: [DictionaryEntry]
    let tierGate: TierGate

    init(reader: any DatabaseReader) throws {
        self.reader = reader
        let entries = try reader.read { db in
            try Self.checkSchemaVersion(in: db)
            return try Self.fetchEntries(
                where: "e.rank <= ? AND e.headword NOT IN (SELECT headword FROM quiz_exclusions)",
                arguments: [TopTier.last.maxRank],
                in: db
            )
        }
        self.quizEntries = entries.filter { $0.primaryRussian != nil }
        self.tierGate = TierGate(cardEntries: quizEntries)
    }

    /// Opens a dictionary file read-only, for example the one bundled with the app.
    public static func open(at url: URL) throws -> DictionaryStore {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw LingvoCoreError.invalidDictionary("no dictionary file at \(url.path)")
        }
        var configuration = Configuration()
        configuration.readonly = true
        return try DictionaryStore(reader: DatabaseQueue(path: url.path, configuration: configuration))
    }

    /// Builds a private in-memory dictionary from JSON sources (tests, previews).
    public static func inMemory(fromJSON sources: [Data]) throws -> DictionaryStore {
        let source = DictionarySource.merged(try sources.map(DictionarySource.decode(json:)))
        let queue = try DatabaseQueue()
        try DictionaryBuilder.write(source, into: queue)
        return try DictionaryStore(reader: queue)
    }

    public func meta() throws -> [String: String] {
        try reader.read { db in
            try Row.fetchAll(db, sql: "SELECT key, value FROM meta").reduce(into: [:]) { result, row in
                result[row["key"]] = row["value"]
            }
        }
    }

    public func entry(headword: String) throws -> DictionaryEntry? {
        try reader.read { db in
            try Self.fetchEntries(where: "e.headword = ?", arguments: [headword], in: db).first
        }
    }

    /// Ignores case and surrounding spaces; an exact-case match wins ("US" over "us").
    func lookupEntry(_ text: String) throws -> DictionaryEntry? {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nil }
        let matches = try reader.read { db in
            try Self.fetchEntries(where: "e.headword = ? COLLATE NOCASE", arguments: [query], in: db)
        }
        return matches.first { $0.headword == query } ?? matches.first
    }

    /// A file built for an older contract lacks tables this code reads; fail with
    /// a clear message instead of an SQL error on the first card.
    private static func checkSchemaVersion(in db: Database) throws {
        let version = try Int.fetchOne(db, sql: "PRAGMA user_version") ?? 0
        guard version == DictionarySchema.schemaVersion else {
            throw LingvoCoreError.invalidDictionary(
                "dictionary schema version \(version), expected \(DictionarySchema.schemaVersion): rebuild it"
            )
        }
    }

    private static func fetchEntries(
        where condition: String,
        arguments: StatementArguments,
        in db: Database
    ) throws -> [DictionaryEntry] {
        let rows = try Row.fetchAll(db, sql: """
            SELECT e.id, e.headword, e.rank, e.pos, e.ipa, e.example, e.synonym_group, e.tier,
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
            translations: translations
        )
    }
}
