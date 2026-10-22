import Foundation
import LingvoCore
import Observation
import Synchronization

/// Where settings are kept. `Tutor` in the app; a stub in snapshots.
protocol SettingsStoring: Sendable {
    var settings: TutorSettings { get }
    func updateSettings(_ settings: TutorSettings) throws
}

extension Tutor: SettingsStoring {}

/// The one place the app changes settings: the Settings window and the tray
/// interval submenu both go through it, so every view shows the same values
/// and the schedule hears about every change.
@MainActor
@Observable
final class SettingsModel {
    private(set) var settings: TutorSettings
    @ObservationIgnored private let store: any SettingsStoring
    @ObservationIgnored private let errors: ErrorPresenter?
    @ObservationIgnored private var listeners: [(_ old: TutorSettings, _ new: TutorSettings) -> Void] = []

    init(store: any SettingsStoring, errors: ErrorPresenter?) {
        self.store = store
        self.errors = errors
        self.settings = store.settings
    }

    /// `listener` runs after each saved change, with the old and the new value.
    func onChange(_ listener: @escaping (_ old: TutorSettings, _ new: TutorSettings) -> Void) {
        listeners.append(listener)
    }

    func update(_ transform: (TutorSettings) -> TutorSettings) {
        let previous = settings
        let updated = transform(previous)
        guard updated != previous else { return }
        do {
            try store.updateSettings(updated)
        } catch {
            errors?.show(error)
            return
        }
        settings = updated
        listeners.forEach { $0(previous, updated) }
    }

    /// The card interval in whole minutes, the unit of the Settings stepper and the onboarding picker.
    var intervalMinutes: Int {
        get { Int((settings.cardInterval / 60).rounded()) }
        set { update { $0.replacing(cardInterval: TimeInterval(newValue) * 60) } }
    }

    func updateLearning(
        direction: DirectionSetting? = nil,
        reviewShare: Double? = nil,
        maxActiveNewWords: Int? = nil
    ) {
        update { current in
            let learning = current.learning
            return current.replacing(learning: LearningSettings(
                direction: direction ?? learning.direction,
                reviewShare: reviewShare ?? learning.reviewShare,
                maxActiveNewWords: maxActiveNewWords ?? learning.maxActiveNewWords
            ))
        }
    }
}

/// Keeps settings in memory only: snapshots must not touch the learner's database.
final class InMemorySettingsStore: SettingsStoring {
    private let stored: Mutex<TutorSettings>

    init(_ settings: TutorSettings = .standard) {
        stored = Mutex(settings)
    }

    var settings: TutorSettings {
        stored.withLock { $0 }
    }

    func updateSettings(_ settings: TutorSettings) throws {
        stored.withLock { $0 = settings }
    }
}
