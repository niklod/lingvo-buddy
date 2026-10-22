import Foundation
import GRDB

/// Read-only access to the extended dictionary, which sits next to the bundled one.
/// It answers only for words the bundled dictionary lacks, so the Tutor asks it second.
public struct ExtendedDictionary: Sendable {
    private let reader: any DatabaseReader

    init(reader: any DatabaseReader) throws {
        self.reader = reader
        try reader.read { db in
            let version = try Int.fetchOne(db, sql: "PRAGMA user_version") ?? 0
            guard version == ExtendedSchema.schemaVersion else {
                throw LingvoCoreError.invalidDictionary(
                    "extended dictionary schema version \(version), expected \(ExtendedSchema.schemaVersion): rebuild it"
                )
            }
        }
    }

    /// Opens the extended dictionary file read-only, for example the one bundled with the app.
    public static func open(at url: URL) throws -> ExtendedDictionary {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw LingvoCoreError.invalidDictionary("no extended dictionary file at \(url.path)")
        }
        var configuration = Configuration()
        configuration.readonly = true
        return try ExtendedDictionary(reader: DatabaseQueue(path: url.path, configuration: configuration))
    }

    /// Builds a private in-memory extended dictionary (tests, previews).
    public static func inMemory(
        english: [ExtendedEntry],
        russian: [ExtendedRussianEntry] = [],
        meta: [String: String] = [:]
    ) throws -> ExtendedDictionary {
        let queue = try DatabaseQueue()
        try ExtendedDictionaryBuilder.write(english: english, russian: russian, meta: meta, into: queue)
        return try ExtendedDictionary(reader: queue)
    }

    public func meta() throws -> [String: String] {
        try reader.read { db in
            try Row.fetchAll(db, sql: "SELECT key, value FROM meta").reduce(into: [:]) { result, row in
                result[row["key"]] = row["value"]
            }
        }
    }

    /// The entry for an English word; case and surrounding spaces are ignored
    /// because the data holds lower-case headwords only.
    public func entry(headword: String) throws -> ExtendedEntry? {
        let key = headword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return try reader.read { db in
            try Row.fetchOne(
                db,
                sql: "SELECT headword, pos, ipa, translations, example, example_ru FROM english WHERE headword = ?",
                arguments: [key]
            ).map(Self.entry(from:))
        }
    }

    /// The English translations of a Russian word, best first, at most `limit`. The match ignores case
    /// and «ё», like the bundled lookup, because the data holds «е» only.
    public func englishTranslations(forRussian text: String, limit: Int) throws -> [String] {
        let key = RussianText.normalized(text)
        let joined: String? = try reader.read { db in
            try String.fetchOne(db, sql: "SELECT translations FROM russian WHERE word = ?", arguments: [key])
        }
        let translations = joined?.split(separator: ExtendedEntry.translationSeparator).map(String.init) ?? []
        return Array(translations.prefix(limit))
    }

    /// How many English and Russian entries the file holds; `lingvo-dict check` prints them.
    public func counts() throws -> (english: Int, russian: Int) {
        try reader.read { db in
            (
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM english") ?? 0,
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM russian") ?? 0
            )
        }
    }

    /// Schema statements in which this file and `ExtendedSchema` differ; empty when they match.
    public func schemaDrift() throws -> [String] {
        let contract = try DatabaseQueue()
        try contract.write { db in try ExtendedSchema.create(in: db) }
        let expected = try contract.read(Self.schemaStatements)
        let actual = try reader.read(Self.schemaStatements)
        return expected.symmetricDifference(actual).sorted()
    }

    /// Whitespace is collapsed: the two writers indent their SQL differently.
    private static func schemaStatements(in db: Database) throws -> Set<String> {
        let statements = try String.fetchAll(db, sql: "SELECT sql FROM sqlite_master WHERE sql IS NOT NULL")
        return Set(statements.map { $0.split(whereSeparator: \.isWhitespace).joined(separator: " ") })
    }

    private static func entry(from row: Row) throws -> ExtendedEntry {
        let headword: String = row["headword"]
        guard let partOfSpeech = PartOfSpeech(rawValue: row["pos"]) else {
            throw LingvoCoreError.invalidDictionary("\(headword): bad pos in the extended dictionary")
        }
        let translations: String = row["translations"]
        return ExtendedEntry(
            headword: headword,
            partOfSpeech: partOfSpeech,
            ipa: row["ipa"],
            translations: translations.split(separator: ExtendedEntry.translationSeparator).map(String.init),
            example: row["example"],
            russianExample: row["example_ru"]
        )
    }
}

/// Writes extended entries into the contract schema for tests and previews, like `DictionaryBuilder`.
enum ExtendedDictionaryBuilder {
    static func write(
        english: [ExtendedEntry],
        russian: [ExtendedRussianEntry],
        meta: [String: String],
        into writer: some DatabaseWriter
    ) throws {
        do {
            try writer.write { db in
                try ExtendedSchema.create(in: db)
                for entry in english {
                    try db.execute(
                        sql: """
                            INSERT INTO english (headword, pos, ipa, translations, example, example_ru)
                            VALUES (?, ?, ?, ?, ?, ?)
                            """,
                        arguments: [
                            entry.headword, entry.partOfSpeech.rawValue, entry.ipa,
                            entry.translations.joined(separator: String(ExtendedEntry.translationSeparator)),
                            entry.example, entry.russianExample,
                        ]
                    )
                }
                for entry in russian {
                    try db.execute(
                        sql: "INSERT INTO russian (word, translations) VALUES (?, ?)",
                        arguments: [
                            entry.word, entry.translations.joined(separator: String(ExtendedEntry.translationSeparator)),
                        ]
                    )
                }
                for (key, value) in meta.sorted(by: { $0.key < $1.key }) {
                    try db.execute(sql: "INSERT INTO meta (key, value) VALUES (?, ?)", arguments: [key, value])
                }
            }
        } catch let error as DatabaseError {
            throw LingvoCoreError.invalidDictionary(error.message ?? error.description)
        }
    }
}
