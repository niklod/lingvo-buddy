import Foundation
import LingvoCore
import Testing

/// User databases that older app versions wrote must open with all their data.
@Suite("User database migrations")
struct MigrationTests {
    /// The schema of the first release (migration v1-progress-and-answers).
    private static let v1Schema = """
        CREATE TABLE word_progress (
            headword TEXT PRIMARY KEY, status TEXT NOT NULL, mastery INTEGER NOT NULL DEFAULT 0,
            last_result TEXT, last_answered_at DATETIME
        );
        CREATE TABLE answers (
            id INTEGER PRIMARY KEY AUTOINCREMENT, headword TEXT NOT NULL, direction TEXT NOT NULL,
            result TEXT NOT NULL, answered_at DATETIME NOT NULL
        );
        CREATE INDEX answers_answered_at ON answers(answered_at);
        """

    /// v1 plus the learning rules, settings and my words (v2–v4), before the Dictionary window.
    private static let v4Schema = v1Schema + """
        ALTER TABLE word_progress ADD COLUMN en_ru_correct BOOLEAN NOT NULL DEFAULT 0;
        ALTER TABLE word_progress ADD COLUMN ru_en_correct BOOLEAN NOT NULL DEFAULT 0;
        ALTER TABLE word_progress ADD COLUMN last_counted_correct_at DATETIME;
        ALTER TABLE word_progress ADD COLUMN review_stage INTEGER NOT NULL DEFAULT 0;
        ALTER TABLE word_progress ADD COLUMN due_at DATETIME;
        ALTER TABLE answers ADD COLUMN kind TEXT;
        CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL);
        CREATE TABLE my_words (
            headword TEXT PRIMARY KEY, translation TEXT NOT NULL, example TEXT, added_at DATETIME NOT NULL
        );
        """
    private static let v4Migrations = ["v1-progress-and-answers", "v2-learning-rules", "v3-settings", "v4-my-words"]

    private func tutor(at url: URL) throws -> Tutor {
        try Fixture.tutor(userDatabase: UserDatabase.open(at: url))
    }

    @Test("a database of the first release keeps its progress and answers")
    func v1DatabaseMigrates() throws {
        let url = try OldUserDatabase.create(migrations: ["v1-progress-and-answers"], sql: Self.v1Schema + """
            INSERT INTO word_progress VALUES
                ('they', 'learned', 4, 'correct', '2026-10-14 09:00:00.000'),
                ('know', 'learning', 1, 'correct', '2026-10-14 10:00:00.000');
            INSERT INTO answers (headword, direction, result, answered_at) VALUES
                ('they', 'en_ru', 'correct', '2026-10-14 09:00:00.000'),
                ('know', 'en_ru', 'wrong', '2026-10-14 09:30:00.000'),
                ('know', 'ru_en', 'correct', '2026-10-14 10:00:00.000');
            """)
        defer { try? FileManager.default.removeItem(at: url) }

        let tutor = try tutor(at: url)
        let stats = try tutor.stats(calendar: Fixture.calendar)
        let card = try #require(try tutor.nextCard().card)

        #expect(stats.tierProgress.learned == 1)
        #expect(stats.learningCount == 1)
        #expect(stats.reviewsLeftToday == 1)
        #expect(stats.todayAnswers == 3)
        #expect(card.headword == "they")
        #expect(card.kind == .review)
        #expect(try tutor.needsOnboarding() == false)
    }

    @Test("a database from before the Dictionary window keeps my words and settings")
    func v4DatabaseMigrates() throws {
        let url = try OldUserDatabase.create(migrations: Self.v4Migrations, sql: Self.v4Schema + """
            INSERT INTO my_words VALUES ('Kubernetes', 'кубернетес', NULL, '2026-10-14 09:00:00.000');
            INSERT INTO settings VALUES
                ('direction', 'en_ru'), ('review_share', '0.3'), ('max_active_new_words', '4'),
                ('card_interval_seconds', '1800.0'), ('quiet_hours_enabled', '0'),
                ('quiet_hours_start', '22:00'), ('quiet_hours_end', '08:00');
            """)
        defer { try? FileManager.default.removeItem(at: url) }

        let tutor = try tutor(at: url)
        try tutor.editTranslation("they", to: "они сами")

        #expect(tutor.settings == TutorSettings(
            learning: LearningSettings(direction: .enToRu, reviewShare: 0.3, maxActiveNewWords: 4),
            cardInterval: 1800,
            quietHours: QuietHours(start: try TimeOfDay(hour: 22, minute: 0), end: try TimeOfDay(hour: 8, minute: 0)),
            quietHoursEnabled: false
        ))
        #expect(!tutor.settings.showsExampleTranslation)
        #expect(try tutor.stats().myWordsCount == 1)
        #expect(try tutor.nextCard().card?.correctAnswer == "кубернетес")
        #expect(try tutor.nextCard().card?.ipa == nil)
        #expect(try tutor.nextCard().card?.partOfSpeech == .other)
        let row = try #require(try tutor.wordList(.myWords).rows.first)
        #expect(row.ipa == nil)
        #expect(row.partOfSpeech == nil)
        #expect(try tutor.wordList(.queue).rows.first { $0.headword == "they" }?.translation == "они сами")
    }

    @Test("broken stored settings fall back to the defaults, and cards still come")
    func brokenSettingsFallBack() throws {
        let url = try OldUserDatabase.create(migrations: Self.v4Migrations, sql: Self.v4Schema + """
            INSERT INTO settings VALUES
                ('direction', 'sideways'), ('review_share', 'abc'), ('max_active_new_words', 'many'),
                ('card_interval_seconds', 'soon'), ('quiet_hours_enabled', 'yes'),
                ('quiet_hours_start', '25:00'), ('quiet_hours_end', 'noon'),
                ('show_example_translation', 'yes'), ('youglish_accent', 'mars');
            """)
        defer { try? FileManager.default.removeItem(at: url) }

        let tutor = try tutor(at: url)

        #expect(tutor.settings == .standard)
        #expect(try tutor.nextCard().card != nil)
    }
}
