import LingvoCore
import SwiftUI

/// Sizes and colours of `design/src/4_dictionary_window.html`.
enum DictionaryLayout {
    static let windowSize = CGSize(width: 1060, height: 660)
    static let minimumSize = CGSize(width: 820, height: 420)
    static let headerHeight: CGFloat = 52
    /// Room for the window's own close, minimise and zoom buttons left of the title.
    static let trafficLightsWidth: CGFloat = 76
    static let sidebarWidth: CGFloat = 220
    static let searchWidth: CGFloat = 260
    static let controlHeight: CGFloat = 30
    static let rowHeight: CGFloat = 44
    static let headerBackground = Color(hex: 0x232325)
    static let sidebarBackground = Color(hex: 0x1A1A1C)
    static let searchBackground = Color(hex: 0x141416)
    static let rowDivider = Color(hex: 0x2A2A2C)
    static let selectedList = Color(hex: 0x0A84FF).opacity(0.22)
}

struct DictionaryActions {
    var addWord: (_ prefill: String?) -> Void = { _ in }
}

/// The Dictionary window content: header with search and "+ Word", the sidebar
/// with lists and rules, and the word table.
struct DictionaryView: View {
    @Bindable var model: DictionaryModel
    let settings: SettingsModel
    var actions = DictionaryActions()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Theme.Palette.border)
            HStack(spacing: 0) {
                DictionarySidebar(model: model, settings: settings.settings)
                    .frame(width: DictionaryLayout.sidebarWidth)
                Rectangle().fill(Theme.Palette.border).frame(width: 1)
                WordTable(model: model)
            }
        }
        .background(Theme.Palette.panel)
        .foregroundStyle(Theme.Palette.textPrimary)
        // The header is the title bar: it fills the space beside the window buttons.
        .ignoresSafeArea(.container, edges: .top)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Text("Dictionary")
                .font(.system(size: Theme.FontSize.title, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            DictionarySearchField(text: $model.search)
            Button { actions.addWord(model.unmatchedSearch) } label: {
                Text("+ Word")
                    .font(.system(size: Theme.FontSize.body, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(height: DictionaryLayout.controlHeight)
                    .background(Theme.Palette.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.smallButton))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(Text("Add a word of your own"))
        }
        .padding(.leading, DictionaryLayout.trafficLightsWidth)
        .padding(.trailing, 16)
        .frame(height: DictionaryLayout.headerHeight)
        .background(DictionaryLayout.headerBackground)
    }
}

struct DictionarySearchField: View {
    @Binding var text: String

    var body: some View {
        TextField(text: $text, prompt: Text("Search word or translation").foregroundStyle(Theme.Palette.textSecondary)) {
            Text("Search")
        }
        .textFieldStyle(.plain)
        .font(.system(size: Theme.FontSize.body))
        .padding(.horizontal, 10)
        .frame(width: DictionaryLayout.searchWidth, height: DictionaryLayout.controlHeight)
        .background(DictionaryLayout.searchBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.smallButton))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.smallButton)
                .strokeBorder(Theme.Palette.border, lineWidth: 1)
        )
    }
}
