import Foundation

/// The pause end, kept in user defaults so "Until tomorrow" survives a restart.
@MainActor
struct PauseStore {
    private static let key = "pausedUntil"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// `nil` when not paused or when the pause is over.
    func pausedUntil(now: Date) -> Date? {
        guard let until = defaults.object(forKey: Self.key) as? Date, until > now else { return nil }
        return until
    }

    func pause(until: Date) {
        defaults.set(until, forKey: Self.key)
    }

    func resume() {
        defaults.removeObject(forKey: Self.key)
    }
}
