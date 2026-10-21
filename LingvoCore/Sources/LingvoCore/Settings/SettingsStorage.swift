import Foundation
import GRDB

/// Settings live in a key/value table: later slices (onboarding, export) add
/// keys without a schema change, and an unknown or broken value falls back to
/// its default instead of failing the whole load.
extension UserDatabase {
    private enum Key {
        static let direction = "direction"
        static let reviewShare = "review_share"
        static let maxActiveNewWords = "max_active_new_words"
        static let cardInterval = "card_interval_seconds"
        static let quietHoursEnabled = "quiet_hours_enabled"
        static let quietHoursStart = "quiet_hours_start"
        static let quietHoursEnd = "quiet_hours_end"
    }

    func settings() throws -> TutorSettings {
        let stored = try writer.read { db in
            try Row.fetchAll(db, sql: "SELECT key, value FROM settings").reduce(into: [String: String]()) {
                $0[$1["key"]] = $1["value"]
            }
        }
        return Self.decode(stored)
    }

    func save(_ settings: TutorSettings) throws {
        try writer.write { db in
            for (key, value) in Self.encode(settings) {
                try db.execute(
                    sql: "INSERT INTO settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value",
                    arguments: [key, value]
                )
            }
        }
    }

    private static func encode(_ settings: TutorSettings) -> [(String, String)] {
        [
            (Key.direction, settings.learning.direction.rawValue),
            (Key.reviewShare, String(settings.learning.reviewShare)),
            (Key.maxActiveNewWords, String(settings.learning.maxActiveNewWords)),
            (Key.cardInterval, String(settings.cardInterval)),
            (Key.quietHoursEnabled, settings.quietHoursEnabled ? "1" : "0"),
            (Key.quietHoursStart, settings.quietHours.start.formatted),
            (Key.quietHoursEnd, settings.quietHours.end.formatted),
        ]
    }

    private static func decode(_ stored: [String: String]) -> TutorSettings {
        let defaults = TutorSettings.standard
        let learning = LearningSettings(
            direction: stored[Key.direction].flatMap(DirectionSetting.init(rawValue:))
                ?? defaults.learning.direction,
            reviewShare: stored[Key.reviewShare].flatMap(Double.init) ?? defaults.learning.reviewShare,
            maxActiveNewWords: stored[Key.maxActiveNewWords].flatMap { Int($0) }
                ?? defaults.learning.maxActiveNewWords
        )
        let quietHours = QuietHours(
            start: stored[Key.quietHoursStart].flatMap(TimeOfDay.init(formatted:)) ?? defaults.quietHours.start,
            end: stored[Key.quietHoursEnd].flatMap(TimeOfDay.init(formatted:)) ?? defaults.quietHours.end
        )
        return TutorSettings(
            learning: learning,
            cardInterval: stored[Key.cardInterval].flatMap(TimeInterval.init) ?? defaults.cardInterval,
            quietHours: quietHours,
            quietHoursEnabled: stored[Key.quietHoursEnabled].map { $0 == "1" } ?? defaults.quietHoursEnabled
        )
    }
}

extension TimeOfDay {
    /// "HH:MM", 24-hour.
    var formatted: String {
        String(format: "%02d:%02d", hour, minute)
    }

    init?(formatted text: String) {
        let parts = text.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2, let time = try? TimeOfDay(hour: parts[0], minute: parts[1]) else { return nil }
        self = time
    }
}
