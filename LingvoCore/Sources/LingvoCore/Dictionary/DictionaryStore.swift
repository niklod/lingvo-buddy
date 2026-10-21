import Foundation
import GRDB

/// Read-only access to a dictionary that follows the bundled contract.
public struct DictionaryStore: Sendable {
    private let reader: any DatabaseReader
    /// The quiz tier is small (1–2k rows) and never changes at runtime, so it is
    /// loaded once; the picker and distractor rules then work without SQL.
    let quizEntries: [DictionaryEntry]

    init(reader: any DatabaseReader) throws {
        self.reader = reader
        self.quizEntries = try reader.read { db in try Self.fetchEntries(tier: .quiz, in: db) }
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

    private static func fetchEntries(tier: DictionaryTier, in db: Database) throws -> [DictionaryEntry] {
        try fetchEntries(where: "e.tier = ?", arguments: [tier.rawValue], in: db)
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
