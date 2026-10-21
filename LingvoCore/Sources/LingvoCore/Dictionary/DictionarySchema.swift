import GRDB

/// The bundled dictionary contract. Every dictionary build (sample or real data)
/// produces exactly these tables, so the app never depends on how the data was made.
enum DictionarySchema {
    static let schemaVersion = 1

    static func create(in db: Database) throws {
        try db.execute(sql: """
            CREATE TABLE entries (
                id INTEGER PRIMARY KEY,
                headword TEXT NOT NULL UNIQUE,
                rank INTEGER NOT NULL UNIQUE,
                pos TEXT NOT NULL CHECK (pos IN (\(quotedList(PartOfSpeech.allCases.map(\.rawValue))))),
                ipa TEXT,
                example TEXT,
                synonym_group TEXT,
                tier TEXT NOT NULL CHECK (tier IN ('quiz', 'lookup'))
            );
            CREATE TABLE translations (
                entry_id INTEGER NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
                lang TEXT NOT NULL,
                ord INTEGER NOT NULL,
                text TEXT NOT NULL,
                PRIMARY KEY (entry_id, lang, ord)
            );
            CREATE INDEX translations_text ON translations(lang, text);
            CREATE TABLE meta (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );
            PRAGMA user_version = \(schemaVersion);
            """)
    }

    private static func quotedList(_ values: [String]) -> String {
        values.map { "'\($0)'" }.joined(separator: ", ")
    }
}
