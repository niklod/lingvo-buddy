import GRDB

/// The extended dictionary contract. tools/dictionary writes the real file with
/// the same statements; `lingvo-dict check` fails when the two drift apart.
enum ExtendedSchema {
    static let schemaVersion = 1

    static func create(in db: Database) throws {
        try db.execute(sql: """
            CREATE TABLE english (
                headword TEXT PRIMARY KEY,
                pos TEXT NOT NULL CHECK (pos IN (\(ReadOnlyDictionaryFile.quotedList(PartOfSpeech.allCases.map(\.rawValue))))),
                ipa TEXT,
                translations TEXT NOT NULL,
                example TEXT,
                example_ru TEXT
            ) WITHOUT ROWID;
            CREATE TABLE russian (
                word TEXT PRIMARY KEY,
                translations TEXT NOT NULL
            ) WITHOUT ROWID;
            CREATE TABLE meta (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );
            PRAGMA user_version = \(schemaVersion);
            """)
    }
}
