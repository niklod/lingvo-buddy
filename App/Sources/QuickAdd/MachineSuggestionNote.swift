import SwiftUI

/// The line under the field the machine translation fills: its label, the
/// download button when the language pack is missing, or a short error.
struct MachineSuggestionNote: View {
    let machine: MachineSuggestion
    /// The field's current text: an edited suggestion is the learner's own, so it loses the label.
    let fieldText: String
    let download: () -> Void

    var body: some View {
        switch machine {
        case .suggested(let suggestion) where suggestion == fieldText:
            Text("machine translation")
                .font(.system(size: Theme.FontSize.small))
                .foregroundStyle(Theme.Palette.chipMineText)
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
