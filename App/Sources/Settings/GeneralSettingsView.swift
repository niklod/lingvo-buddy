import AppKit
import KeyboardShortcuts
import LingvoCore
import SwiftUI

/// Every option takes effect at once: the model saves each change and the
/// schedule and picker read the new value for the next card.
struct GeneralSettingsView: View {
    @Bindable var model: SettingsModel
    let launchAtLogin: any LaunchAtLoginControlling
    let errors: ErrorPresenter?
    let transfer: CSVTransferActions

    var body: some View {
        VStack(alignment: .leading, spacing: SettingsLayout.sectionSpacing) {
            ScheduleSection(model: model)
            LearningSection(model: model)
            SystemSection(launchAtLogin: launchAtLogin, errors: errors)
            ShortcutsSection()
            DataSettingsSection(transfer: transfer)
        }
    }
}

private struct ScheduleSection: View {
    @Bindable var model: SettingsModel

    var body: some View {
        SettingsSection(title: String(localized: "Cards")) {
            SettingsRow(label: String(localized: "Show a card")) {
                ValueStepper(
                    text: String(localized: "every \(model.intervalMinutes) min"),
                    value: $model.intervalMinutes,
                    range: SettingsRanges.intervalMinutes,
                    step: SettingsRanges.intervalStep
                )
            }
            SettingsDivider()
            SettingsRow(
                label: String(localized: "Quiet hours"),
                hint: String(localized: "No timed cards in this span. \"Show word now\" still works.")
            ) {
                HStack(spacing: 8) {
                    TimeOfDayPicker(time: quietStart).disabled(!model.settings.quietHoursEnabled)
                    Text("–").foregroundStyle(Theme.Palette.textSecondary)
                    TimeOfDayPicker(time: quietEnd).disabled(!model.settings.quietHoursEnabled)
                    Toggle("", isOn: quietEnabled).labelsHidden().toggleStyle(.switch).controlSize(.small)
                }
            }
        }
    }

    private var quietEnabled: Binding<Bool> {
        Binding(
            get: { model.settings.quietHoursEnabled },
            set: { isOn in model.update { $0.replacing(quietHoursEnabled: isOn) } }
        )
    }

    private var quietStart: Binding<TimeOfDay> {
        Binding(
            get: { model.settings.quietHours.start },
            set: { start in
                model.update { $0.replacing(quietHours: QuietHours(start: start, end: $0.quietHours.end)) }
            }
        )
    }

    private var quietEnd: Binding<TimeOfDay> {
        Binding(
            get: { model.settings.quietHours.end },
            set: { end in
                model.update { $0.replacing(quietHours: QuietHours(start: $0.quietHours.start, end: end)) }
            }
        )
    }
}

private struct LearningSection: View {
    @Bindable var model: SettingsModel

    var body: some View {
        SettingsSection(title: String(localized: "Learning")) {
            SettingsRow(
                label: String(localized: "Direction"),
                hint: String(localized: "Mix shows about 70% of new words as EN → RU.")
            ) {
                Picker("", selection: direction) {
                    Text("EN → RU").tag(DirectionSetting.enToRu)
                    Text("RU → EN").tag(DirectionSetting.ruToEn)
                    Text(String(localized: "Mix")).tag(DirectionSetting.mix)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .fixedSize()
            }
            SettingsDivider()
            SettingsRow(label: String(localized: "Reviews")) {
                ValueStepper(
                    text: String(localized: "up to \(reviewPercent.wrappedValue)% of cards"),
                    value: reviewPercent,
                    range: SettingsRanges.reviewPercent,
                    step: SettingsRanges.reviewPercentStep
                )
            }
            SettingsDivider()
            SettingsRow(
                label: String(localized: "New words in progress"),
                hint: String(localized: "A new word starts only while fewer words than this are in learning.")
            ) {
                ValueStepper(
                    text: String(localized: "at most \(maxActive.wrappedValue)"),
                    value: maxActive,
                    range: SettingsRanges.maxActiveNewWords,
                    step: 1
                )
            }
            SettingsDivider()
            SettingsRow(
                label: String(localized: "Show example translation"),
                hint: String(localized: "The Russian line under the example, after the answer and in quick add.")
            ) {
                Toggle("", isOn: showsExampleTranslation).labelsHidden().toggleStyle(.switch).controlSize(.small)
            }
        }
    }

    private var showsExampleTranslation: Binding<Bool> {
        Binding(
            get: { model.settings.showsExampleTranslation },
            set: { isOn in model.update { $0.replacing(showsExampleTranslation: isOn) } }
        )
    }

    private var direction: Binding<DirectionSetting> {
        Binding(
            get: { model.settings.learning.direction },
            set: { model.updateLearning(direction: $0) }
        )
    }

    private var reviewPercent: Binding<Int> {
        Binding(
            get: { Int((model.settings.learning.reviewShare * 100).rounded()) },
            set: { model.updateLearning(reviewShare: Double($0) / 100) }
        )
    }

    private var maxActive: Binding<Int> {
        Binding(
            get: { model.settings.learning.maxActiveNewWords },
            set: { model.updateLearning(maxActiveNewWords: $0) }
        )
    }
}

private struct SystemSection: View {
    let launchAtLogin: any LaunchAtLoginControlling
    let errors: ErrorPresenter?

    var body: some View {
        SettingsSection(title: String(localized: "System")) {
            LaunchAtLoginRow(launchAtLogin: launchAtLogin, errors: errors)
        }
    }
}

private struct ShortcutsSection: View {
    var body: some View {
        SettingsSection(title: String(localized: "Shortcuts")) {
            ForEach(HotKeys.configurable, id: \.name.rawValue) { hotKey in
                SettingsRow(label: hotKey.title) {
                    KeyboardShortcuts.Recorder(for: hotKey.name)
                }
            }
        }
    }
}

/// The limits the Settings window offers (spec: interval 5–120 min).
enum SettingsRanges {
    static let intervalMinutes = Int(CardScheduleSettings.intervalRange.lowerBound / 60)...Int(CardScheduleSettings.intervalRange.upperBound / 60)
    static let intervalStep = 5
    static let reviewPercent = 0...50
    static let reviewPercentStep = 5
    static let maxActiveNewWords = 1...30
}
