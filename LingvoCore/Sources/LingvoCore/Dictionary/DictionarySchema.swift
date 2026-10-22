import GRDB

/// The bundled dictionary contract. tools/dictionary writes the real file with
/// the same statements; `lingvo-dict check` fails when the two drift apart.
enum DictionarySchema {
    static let schemaVersion = 3

    static func create(in db: Database) throws {
        try db.execute(sql: """
            CREATE TABLE entries (
                id INTEGER PRIMARY KEY,
                headword TEXT NOT NULL UNIQUE,
                rank INTEGER NOT NULL UNIQUE,
                pos TEXT NOT NULL CHECK (pos IN (\(quotedList(PartOfSpeech.allCases.map(\.rawValue))))),
                ipa TEXT NOT NULL,
                example TEXT,
                example_ru TEXT,
                synonym_group TEXT,
                tier TEXT NOT NULL CHECK (tier IN (\(quotedList(DictionaryTier.allCases.map(\.rawValue)))))
            );
            CREATE TABLE translations (
                entry_id INTEGER NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
                lang TEXT NOT NULL,
                ord INTEGER NOT NULL,
                text TEXT NOT NULL,
                PRIMARY KEY (entry_id, lang, ord)
            );
            CREATE INDEX translations_text ON translations(lang, text);
            CREATE TABLE quiz_exclusions (
                headword TEXT PRIMARY KEY REFERENCES entries(headword)
            );
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
