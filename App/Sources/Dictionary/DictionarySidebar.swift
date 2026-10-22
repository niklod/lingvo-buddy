import LingvoCore
import SwiftUI

/// "Lists" with counts, then the read-only "Rules" from the current settings.
struct DictionarySidebar: View {
    @Bindable var model: DictionaryModel
    let settings: TutorSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            sectionTitle("Lists", top: 6)
            ForEach(WordList.allCases, id: \.self) { list in
                listRow(list)
            }
            sectionTitle("Rules", top: 14)
            VStack(spacing: 8) {
                ForEach(DictionaryLabels.rules(settings), id: \.label) { rule in
                    HStack(spacing: 4) {
                        Text(rule.label).foregroundStyle(Theme.Palette.textBody)
                        Spacer(minLength: 4)
                        Text(rule.value).foregroundStyle(Theme.Palette.textSecondary)
                    }
                    .lineLimit(1)
                }
            }
            .font(.system(size: Theme.FontSize.caption))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.Palette.sidebar)
    }

    private func sectionTitle(_ title: LocalizedStringKey, top: CGFloat) -> some View {
        Text(title)
            .textCase(.uppercase)
            .font(.system(size: Theme.FontSize.small, weight: .semibold))
            .foregroundStyle(Theme.Palette.textSecondary)
            .padding(.top, top)
            .padding(.bottom, 6)
            .padding(.horizontal, 8)
    }

    private func listRow(_ list: WordList) -> some View {
        let isSelected = model.list == list
        return Button { model.list = list } label: {
            HStack {
                Text(DictionaryLabels.title(of: list, queueTier: model.page.queueTier))
                    .foregroundStyle(isSelected ? Theme.Palette.textStrong : Theme.Palette.textBody)
                Spacer()
                Text("\(model.page.counts[list] ?? 0)")
                    .foregroundStyle(isSelected ? Theme.Palette.textStrong : Theme.Palette.textSecondary)
                    .monospacedDigit()
            }
            .font(.system(size: Theme.FontSize.body))
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(
                isSelected ? DictionaryLayout.selectedList : .clear,
                in: RoundedRectangle(cornerRadius: Theme.Radius.chip)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
