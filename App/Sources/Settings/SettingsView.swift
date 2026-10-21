import SwiftUI

enum SettingsTab: String, CaseIterable {
    case general
    case about

    var title: String {
        switch self {
        case .general: String(localized: "General")
        case .about: String(localized: "About")
        }
    }
}

/// Selected-tab state lives outside the view so `openSettings(tab:)` can switch it.
@MainActor
@Observable
final class SettingsNavigation {
    var tab: SettingsTab

    init(tab: SettingsTab = .general) {
        self.tab = tab
    }
}

struct SettingsView: View {
    let model: SettingsModel
    @Bindable var navigation: SettingsNavigation
    let launchAtLogin: any LaunchAtLoginControlling
    let about: AboutInfo
    let errors: ErrorPresenter?
    let transfer: CSVTransferActions

    var body: some View {
        VStack(spacing: SettingsLayout.sectionSpacing) {
            Picker("", selection: $navigation.tab) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .fixedSize()
            switch navigation.tab {
            case .general:
                GeneralSettingsView(model: model, launchAtLogin: launchAtLogin, errors: errors, transfer: transfer)
            case .about:
                AboutView(info: about)
            }
        }
        .padding(SettingsLayout.padding)
        .frame(width: SettingsLayout.width, alignment: .top)
        .background(Theme.Palette.panel)
        .tint(Theme.Palette.accent)
        .environment(\.colorScheme, .dark)
    }
}
