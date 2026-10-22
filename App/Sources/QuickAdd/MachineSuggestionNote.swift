import LingvoCore
import SwiftUI

/// The line under the custom field when the machine translation has no bubble:
/// the download button when the language pack is missing, or a short error.
/// A result shows as a marked bubble instead (`TranslationPill`).
struct MachineSuggestionNote: View {
    let machine: MachineSuggestion
    let download: () -> Void

    var body: some View {
        switch machine {
        case .languagePackMissing, .downloading:
            downloadRow
        case .failed:
            Text("Machine translation failed. Type it yourself.")
                .font(.system(size: Theme.FontSize.small))
                .foregroundStyle(Theme.Palette.wrongText)
        case .none, .waiting, .suggested:
            EmptyView()
        }
    }

    private var downloadRow: some View {
        HStack(spacing: 8) {
            Button(String(localized: "Download offline translation"), action: download)
                .buttonStyle(.footer(.secondary))
                .disabled(machine == .downloading)
            Text("Machine translation needs the offline language pack.")
                .font(.system(size: Theme.FontSize.small))
                .foregroundStyle(Theme.Palette.textSecondary)
                .lineLimit(2)
        }
    }
}
