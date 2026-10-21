import Foundation
import LingvoCore

/// The card interval the learner chose (tray submenu, later Settings), kept in user defaults.
@MainActor
struct IntervalStore {
    private static let key = "cardIntervalSeconds"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The stored interval, or the 15 min default. A stored value outside the
    /// Settings range (an old or hand-edited value) falls back to the default.
    func settings() -> CardScheduleSettings {
        let stored = defaults.double(forKey: Self.key)
        guard CardScheduleSettings.intervalRange.contains(stored),
              let settings = try? CardScheduleSettings(interval: stored) else {
            return .standard
        }
        return settings
    }

    func save(_ settings: CardScheduleSettings) {
        defaults.set(settings.interval, forKey: Self.key)
    }
}
