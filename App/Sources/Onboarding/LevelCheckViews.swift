import LingvoCore
import SwiftUI

struct LevelIntroView: View {
    let model: OnboardingModel
    let sample: LevelCheckSample

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.spacing) {
            OnboardingHeader(
                step: model.step,
                title: String(localized: "Quick level check"),
                text: String(localized: """
                    You see \(sample.words.count) words from the Top‑\(String(sample.tier.maxRank)). Answer "Know" or "Don't know" \
                    for each. Words you know, and the easier words below your level, are marked learned, so \
                    cards start where you are.
                    """)
            )
            HStack {
                OnboardingLinkButton(title: String(localized: "Skip the check")) { model.skipLevelCheck() }
                Spacer()
                OnboardingButton(title: String(localized: "Start check")) { model.startLevelCheck() }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }
}

/// One sample word: "Know ↵" or "Don't know ⌫". The translation is not shown,
/// so the answer is about the English word.
struct LevelWordView: View {
    let model: OnboardingModel
    let word: DictionaryEntry
    let index: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.spacing) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(String(localized: "Word \(index + 1) of \(total)"))
                    Spacer()
                    Text(verbatim: "#\(word.rank)")
                }
                .font(.system(size: Theme.FontSize.caption).monospacedDigit())
                .foregroundStyle(Theme.Palette.textSecondary)
                OnboardingProgressBar(done: index, total: total)
            }
            VStack(spacing: 6) {
                Text(verbatim: word.headword)
                    .font(.system(size: Theme.FontSize.word, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textStrong)
                Text(verbatim: subtitle)
                    .font(.system(size: Theme.FontSize.body))
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(Theme.Palette.raised.opacity(0.5), in: RoundedRectangle(cornerRadius: Theme.Radius.option))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.option).strokeBorder(Theme.Palette.border))
            HStack(spacing: 8) {
                OnboardingLinkButton(title: String(localized: "Finish now")) { model.finishLevelCheck() }
                Spacer()
                OnboardingButton(title: String(localized: "Don't know ⌫"), kind: .secondary) {
                    model.answer(knows: false)
                }
                .keyboardShortcut(.delete, modifiers: [])
                OnboardingButton(title: String(localized: "Know ↵")) { model.answer(knows: true) }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var subtitle: String {
        let partOfSpeech = word.partOfSpeech.label
        guard let ipa = word.ipa else { return partOfSpeech }
        return "\(ipa) · \(partOfSpeech)"
    }
}

struct LevelDoneView: View {
    let model: OnboardingModel
    let outcome: LevelCheckOutcome

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.spacing) {
            OnboardingHeader(step: model.step, title: String(localized: "Level check done"), text: text)
            HStack {
                Spacer()
                OnboardingButton(title: String(localized: "Continue")) { model.showSetup() }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var text: String {
        guard outcome.learnedCount > 0 else {
            return String(localized: "No words are marked learned. Cards start with the most frequent words.")
        }
        return String(localized: """
            \(outcome.learnedCount) words are marked learned. They come back now and then as reviews. \
            New cards start with the easiest words you do not know yet.
            """)
    }
}
