#if DEBUG
import LingvoCore
import SwiftUI

/// Onboarding is not designed, so these names have no design screenshot. The
/// states use a fixed sample, in-memory settings and fixed system states.
@MainActor
enum OnboardingSnapshots {
    /// The word on screen in `onboarding_level_word` (Word 7 of 30).
    private static let shownIndex = 6

    static var states: [SnapshotState] {
        [
            state("onboarding_welcome", step: .welcome),
            state("onboarding_level_intro", step: .levelIntro),
            state("onboarding_level_word", step: .levelWord(index: shownIndex)),
            state("onboarding_level_done", step: .levelDone(LevelCheckOutcome(learnedCount: 412, levelRank: 640))),
            state("onboarding_level_done_none", step: .levelDone(LevelCheckOutcome(learnedCount: 0, levelRank: nil))),
            state("onboarding_setup", step: .setup, focus: .unavailable),
            state("onboarding_setup_focus_ask", step: .setup, focus: .notAsked, login: .on),
        ]
    }

    /// 30 words like a real Top‑1000 sample; "although" #312 from the design is the one on screen.
    static var sample: LevelCheckSample {
        let words = (0..<LevelCheckSample.defaultSize).map { index in
            index == shownIndex ? although : filler(rank: index * 33 + 3)
        }
        return LevelCheckSample(tier: .top1000, words: words)
    }

    private static let although = DictionaryEntry(
        headword: "although",
        rank: 312,
        partOfSpeech: .conjunction,
        ipa: "/ɔːlˈðəʊ/",
        example: "Although it was late, we kept working.",
        synonymGroup: "although",
        tier: .quiz,
        translations: [.russian: ["хотя"]]
    )

    private static func filler(rank: Int) -> DictionaryEntry {
        DictionaryEntry(
            headword: "word\(rank)",
            rank: rank,
            partOfSpeech: .noun,
            ipa: nil,
            example: nil,
            synonymGroup: nil,
            tier: .quiz,
            translations: [.russian: ["слово"]]
        )
    }

    private static func state(
        _ name: String,
        step: OnboardingStep,
        focus: FocusAccess = .unavailable,
        login: LaunchAtLoginState = .off
    ) -> SnapshotState {
        SnapshotState(name: name, usesWindow: true) {
            let store = SampleOnboardingStore(sample: sample, outcome: LevelCheckOutcome(learnedCount: 0, levelRank: nil))
            return AnyView(OnboardingView(
                model: OnboardingModel(store: store, errors: nil, step: step, sample: sample),
                settings: SettingsModel(store: InMemorySettingsStore(), errors: nil),
                focus: FixedFocusAccess(focus),
                launchAtLogin: FixedLaunchAtLogin(login),
                errors: nil
            ))
        }
    }
}
#endif
