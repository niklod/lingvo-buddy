/// The user database migrations, oldest first. A shipped migration never
/// changes: databases of older app versions already ran it.
enum UserSchema {
    static let migrations: [(name: String, sql: String)] = [
        ("v1-progress-and-answers", """
            CREATE TABLE word_progress (
                headword TEXT PRIMARY KEY,
                status TEXT NOT NULL,
                mastery INTEGER NOT NULL DEFAULT 0,
                last_result TEXT,
                last_answered_at DATETIME
            );
            CREATE TABLE answers (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                headword TEXT NOT NULL,
                direction TEXT NOT NULL,
                result TEXT NOT NULL,
                answered_at DATETIME NOT NULL
            );
            CREATE INDEX answers_answered_at ON answers(answered_at);
            """),
        ("v2-learning-rules", """
            ALTER TABLE word_progress ADD COLUMN en_ru_correct BOOLEAN NOT NULL DEFAULT 0;
            ALTER TABLE word_progress ADD COLUMN ru_en_correct BOOLEAN NOT NULL DEFAULT 0;
            ALTER TABLE word_progress ADD COLUMN last_counted_correct_at DATETIME;
            ALTER TABLE word_progress ADD COLUMN review_stage INTEGER NOT NULL DEFAULT 0;
            ALTER TABLE word_progress ADD COLUMN due_at DATETIME;
            ALTER TABLE answers ADD COLUMN kind TEXT;
            """),
        ("v3-settings", """
            CREATE TABLE settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );
            """),
        ("v4-my-words", """
            CREATE TABLE my_words (
                headword TEXT PRIMARY KEY,
                translation TEXT NOT NULL,
                example TEXT,
                added_at DATETIME NOT NULL
            );
            """),
        ("v6-dictionary", """
            CREATE TABLE translation_overrides (
                headword TEXT PRIMARY KEY,
                translation TEXT NOT NULL
            );
            """),
        // The tier check runs on every card and keystroke, and quick add looks up
        // my words ignoring case: without these both scan a whole table.
        ("v7-lookup-indexes", """
            CREATE INDEX answers_headword_kind ON answers(headword, kind);
            CREATE INDEX my_words_headword_nocase ON my_words(headword COLLATE NOCASE);
            """),
        // Nullable: my words added before this keep empty values and look as they did.
        ("v8-my-word-details", """
            ALTER TABLE my_words ADD COLUMN ipa TEXT;
            ALTER TABLE my_words ADD COLUMN pos TEXT;
            """),
    ]
}
