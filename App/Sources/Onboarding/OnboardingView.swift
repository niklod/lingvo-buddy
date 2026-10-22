import LingvoCore
import SwiftUI

struct OnboardingView: View {
    let model: OnboardingModel
    let settings: SettingsModel
    let focus: any FocusAccessRequesting
    let launchAtLogin: any LaunchAtLoginControlling
    let errors: ErrorPresenter?

    var body: some View {
        content
            .padding(OnboardingLayout.padding)
            .frame(width: OnboardingLayout.width, alignment: .top)
            .background(Theme.Palette.panel)
            .tint(Theme.Palette.accent)
            .environment(\.colorScheme, .dark)
    }

    @ViewBuilder private var content: some View {
        switch model.step {
        case .welcome:
            WelcomeView(model: model, settings: settings)
        case .levelIntro:
            if let sample = model.sample {
                LevelIntroView(model: model, sample: sample)
            }
        case .levelWord(let index):
            if let word = model.currentWord {
                LevelWordView(model: model, word: word, index: index, total: model.sample?.words.count ?? 0)
            }
        case .levelDone(let outcome):
            LevelDoneView(model: model, outcome: outcome)
        case .setup:
            SetupView(model: model, focus: focus, launchAtLogin: launchAtLogin, errors: errors)
        }
    }
}

private struct WelcomeView: View {
    /// Short list for the first choice; Settings offers every 5 min step from 5 to 120.
    static let intervalChoices = [5, 10, 15, 30, 60]

    let model: OnboardingModel
    let settings: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.spacing) {
            OnboardingHeader(
                step: model.step,
                title: String(localized: "Welcome to LingvoBuddy"),
                text: String(localized: """
                    LingvoBuddy shows a small word card from time to time while you work. It never takes \
                    your keyboard focus. Answer in a few seconds, or ignore the card: it closes on its own.
                    """)
            )
            SettingsSection(title: String(localized: "Show a card")) {
                Picker("", selection: intervalMinutes) {
                    ForEach(choices, id: \.self) { minutes in
                        Text(String(localized: "\(minutes) min")).tag(minutes)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                Text(String(localized: "Every 15 min suits most people. You can change it later in Settings."))
                    .font(.system(size: Theme.FontSize.small))
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            HStack {
                Spacer()
                Button(String(localized: "Continue")) { model.showLevelIntro() }
                    .buttonStyle(.onboarding())
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    /// The stored interval stays selectable even when it is not one of the short choices.
    private var choices: [Int] {
        Set(Self.intervalChoices + [intervalMinutes.wrappedValue]).sorted()
    }

    private var intervalMinutes: Binding<Int> {
        Bindable(settings).intervalMinutes
    }
}

private struct SetupView: View {
    let model: OnboardingModel
    let focus: any FocusAccessRequesting
    let launchAtLogin: any LaunchAtLoginControlling
    let errors: ErrorPresenter?
    @State private var focusAccess: FocusAccess?

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.spacing) {
            OnboardingHeader(
                step: model.step,
                title: String(localized: "Two more things"),
                text: String(localized: "Both are optional. You can change them later.")
            )
            SettingsSection(title: String(localized: "Focus")) {
                FocusAccessRow(access: focusAccess ?? focus.access) {
                    focus.requestAccess { focusAccess = $0 }
                }
            }
            SettingsSection(title: String(localized: "System")) {
                LaunchAtLoginRow(
                    launchAtLogin: launchAtLogin,
                    errors: errors,
                    hintWhenOff: String(localized: "Cards continue after a restart without a click from you.")
                )
            }
            HStack {
                Spacer()
                Button(String(localized: "Start learning")) { model.finish() }
                    .buttonStyle(.onboarding())
                    .keyboardShortcut(.defaultAction)
            }
        }
    }
}

/// Honest about the ad-hoc build: macOS gives Focus status only to apps with a
/// restricted entitlement, so the row explains what still works instead.
private struct FocusAccessRow: View {
    let access: FocusAccess
    let request: () -> Void

    var body: some View {
        SettingsRow(label: String(localized: "No cards while a Focus is on"), hint: hint) {
            switch access {
            case .notAsked:
                Button(String(localized: "Allow…"), action: request).controlSize(.small)
            case .allowed:
                status(String(localized: "Allowed"), color: Theme.Palette.success)
            case .denied:
                status(String(localized: "Not allowed"), color: Theme.Palette.wrongText)
            case .unavailable:
                status(String(localized: "Not available"), color: Theme.Palette.textSecondary)
            }
        }
    }

    private func status(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: Theme.FontSize.caption, weight: .medium))
            .foregroundStyle(color)
    }

    private var hint: String {
        switch access {
        case .notAsked:
            String(localized: "macOS asks once. LingvoBuddy reads only whether a Focus is on.")
        case .allowed:
            String(localized: "Timed cards wait while a Focus is on.")
        case .denied:
            String(localized: "Allow LingvoBuddy in System Settings > Privacy & Security > Focus.")
        case .unavailable:
            String(localized: """
                This build cannot read Focus status: macOS allows it only for apps signed with a special \
                Apple permission. Cards still stop in quiet hours and while a full-screen app is in front.
                """)
        }
    }
}
