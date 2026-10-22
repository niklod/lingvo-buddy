#if DEBUG
import LingvoCore
import SwiftUI

/// Settings is not designed, so these names have no design screenshot.
/// The states use in-memory settings and a fixed login-item state.
@MainActor
enum SettingsSnapshots {
    static let sampleAbout = AboutInfo(
        version: "0.1.0",
        build: "1",
        attribution: "Word frequencies: wordfreq by Robyn Speer, CC BY-SA 4.0, https://github.com/rspeer/wordfreq. "
            + "Translations, transcriptions and examples: LingvoBuddy.",
        source: "wordfreq 3.1.1 (en)",
        wiktionaryCredit: "Word translations, transcriptions and examples: Wiktionary contributors "
            + "(en.wiktionary.org, ru.wiktionary.org), via kaikki.org, CC BY-SA 4.0, "
            + "https://creativecommons.org/licenses/by-sa/4.0/. Modified: cleaned, shortened and merged."
    )

    static var states: [SnapshotState] {
        [
            state("settings_general", tab: .general, settings: .standard, login: .off),
            state("settings_general_custom", tab: .general, settings: custom, login: .needsApproval),
            state("settings_about", tab: .about, settings: .standard, login: .off),
        ]
    }

    /// Non-default values in every control, quiet hours off, example translation on, British YouGlish accent, login item waiting for approval.
    private static var custom: TutorSettings {
        TutorSettings(
            learning: LearningSettings(direction: .ruToEn, reviewShare: 0.3, maxActiveNewWords: 6),
            cardInterval: 45 * 60,
            quietHours: .standard,
            quietHoursEnabled: false,
            showsExampleTranslation: true,
            youGlishAccent: .uk
        )
    }

    private static func state(
        _ name: String,
        tab: SettingsTab,
        settings: TutorSettings,
        login: LaunchAtLoginState
    ) -> SnapshotState {
        SnapshotState(name: name, usesWindow: true) {
            AnyView(SettingsView(
                model: SettingsModel(store: InMemorySettingsStore(settings), errors: nil),
                navigation: SettingsNavigation(tab: tab),
                launchAtLogin: FixedLaunchAtLogin(login),
                about: sampleAbout,
                errors: nil,
                transfer: .none
            ))
        }
    }
}
#endif
