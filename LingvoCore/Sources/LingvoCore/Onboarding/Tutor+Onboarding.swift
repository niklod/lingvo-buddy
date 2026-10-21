import Foundation
import GRDB

extension Tutor {
    /// `true` on the first run only. A learner who already answered cards (the
    /// app ran before onboarding shipped) is not new and does not get it.
    public func needsOnboarding() throws -> Bool {
        try !userDatabase.isOnboardingCompleted() && !userDatabase.hasAnyAnswer()
    }

    /// Finishing and skipping both end onboarding for good.
    public func completeOnboarding() throws {
        try userDatabase.markOnboardingCompleted(at: clock.now())
    }
}

/// The flag lives in the `settings` key/value table: no migration needed.
extension UserDatabase {
    private static let onboardingCompletedKey = "onboarding_completed_at"

    func isOnboardingCompleted() throws -> Bool {
        try writer.read { db in
            try Bool.fetchOne(
                db,
                sql: "SELECT EXISTS (SELECT 1 FROM settings WHERE key = ?)",
                arguments: [Self.onboardingCompletedKey]
            ) ?? false
        }
    }

    func markOnboardingCompleted(at time: Date) throws {
        try writer.write { db in
            try db.execute(
                sql: "INSERT INTO settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO NOTHING",
                arguments: [Self.onboardingCompletedKey, ISO8601DateFormatter().string(from: time)]
            )
        }
    }

    func hasAnyAnswer() throws -> Bool {
        try writer.read { db in
            try Bool.fetchOne(db, sql: "SELECT EXISTS (SELECT 1 FROM answers)") ?? false
        }
    }
}
