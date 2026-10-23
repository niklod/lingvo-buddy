import LingvoCore
import SwiftUI

/// The design's grid: 2fr 2fr 1.4fr 1.2fr 1fr with 12 pt gaps and 20 pt sides.
struct WordTableColumns {
    private static let fractions: [CGFloat] = [2, 2, 1.4, 1.2, 1]
    static let gap: CGFloat = 12
    static let sidePadding: CGFloat = 20

    let widths: [CGFloat]

    init(totalWidth: CGFloat) {
        let free = max(totalWidth - 2 * Self.sidePadding - Self.gap * CGFloat(Self.fractions.count - 1), 0)
        let unit = free / Self.fractions.reduce(0, +)
        widths = Self.fractions.map { ($0 * unit).rounded(.down) }
    }
}

/// The word table of the selected list. Right-click a row for its actions.
struct WordTable: View {
    @Bindable var model: DictionaryModel
    @State private var editing: WordRow?
    @State private var confirming: PendingConfirmation?

    var body: some View {
        GeometryReader { proxy in
            let columns = WordTableColumns(totalWidth: proxy.size.width)
            VStack(spacing: 0) {
                headerRow(columns)
                Rectangle().fill(Theme.Palette.border).frame(height: 1)
                if model.page.rows.isEmpty {
                    emptyState
                } else {
                    rows(columns)
                }
            }
        }
        .sheet(item: $editing) { row in
            TranslationEditSheet(row: row) { text in
                model.perform(.editTranslation(text), on: row)
            }
        }
        .confirmationDialog(
            confirming?.title ?? "",
            isPresented: isConfirming,
            presenting: confirming
        ) { pending in
            Button(pending.button, role: .destructive) { model.perform(pending.action, on: pending.row) }
            Button("Cancel", role: .cancel) {}
        } message: { pending in
            Text(pending.message)
        }
    }

    private func headerRow(_ columns: WordTableColumns) -> some View {
        let titles: [LocalizedStringKey] = ["Word", "Translation", "Mastery", "Last answer", "Source"]
        return HStack(spacing: WordTableColumns.gap) {
            ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                Text(title)
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .frame(width: columns.widths[index], alignment: .leading)
            }
        }
        .font(.system(size: Theme.FontSize.small, weight: .semibold))
        .foregroundStyle(Theme.Palette.textSecondary)
        .padding(.horizontal, WordTableColumns.sidePadding)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func rows(_ columns: WordTableColumns) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(model.page.rows) { row in
                    WordTableRow(row: row, columns: columns, now: model.loadedAt)
                        .contextMenu { menu(for: row) }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .hidingTitleBarEdgeEffect()
    }

    @ViewBuilder
    private func menu(for row: WordRow) -> some View {
        Button("Edit translation…") { editing = row }
        Button("Delete…") { confirming = .delete(row) }
            .disabled(!row.canDelete)
        Button("Reset progress…") { confirming = .reset(row) }
            .disabled(!row.canResetProgress)
        Button("Mark as learned") { model.perform(.markLearned, on: row) }
            .disabled(!row.canMarkLearned)
    }

    private var emptyState: some View {
        Text(DictionaryLabels.emptyList(search: model.search))
            .font(.system(size: Theme.FontSize.body))
            .foregroundStyle(Theme.Palette.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var isConfirming: Binding<Bool> {
        Binding(get: { confirming != nil }, set: { if !$0 { confirming = nil } })
    }
}

/// A destructive row action waiting for the learner's "yes".
struct PendingConfirmation {
    let row: WordRow
    let action: RowAction
    let title: String
    let message: String
    let button: String

    static func delete(_ row: WordRow) -> PendingConfirmation {
        PendingConfirmation(
            row: row,
            action: .delete,
            title: String(localized: "Delete “\(row.headword)”?"),
            message: String(localized: "The word and its progress are removed from My words."),
            button: String(localized: "Delete")
        )
    }

    static func reset(_ row: WordRow) -> PendingConfirmation {
        PendingConfirmation(
            row: row,
            action: .resetProgress,
            title: String(localized: "Reset progress of “\(row.headword)”?"),
            message: String(localized: "Its mastery goes back to zero and it is learned again from the start."),
            button: String(localized: "Reset")
        )
    }
}

struct WordTableRow: View {
    let row: WordRow
    let columns: WordTableColumns
    let now: Date

    var body: some View {
        HStack(spacing: WordTableColumns.gap) {
            wordCell(width: columns.widths[0])
            Text(row.translation)
                .foregroundStyle(Theme.Palette.textBody)
                .frame(width: columns.widths[1], alignment: .leading)
            MasteryDots(filled: row.mastery)
                .accessibilityElement()
                .accessibilityLabel(Text("Mastery \(row.mastery) of \(WordRow.masteryGoal)"))
                .frame(width: columns.widths[2], alignment: .leading)
            Text(DictionaryLabels.lastAnswer(row.lastAnswer, now: now))
                .foregroundStyle(DictionaryLabels.lastAnswerColor(row.lastAnswer))
                .frame(width: columns.widths[3], alignment: .leading)
            Text(DictionaryLabels.source(row.source))
                .foregroundStyle(Theme.Palette.textSecondary)
                .frame(width: columns.widths[4], alignment: .leading)
        }
        .lineLimit(1)
        .truncationMode(.tail)
        .font(.system(size: Theme.FontSize.body))
        .padding(.horizontal, WordTableColumns.sidePadding)
        .frame(height: DictionaryLayout.rowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle().fill(DictionaryLayout.rowDivider).frame(height: 1)
        }
        .contentShape(Rectangle())
    }

    private func wordCell(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(row.headword)
                .fontWeight(.semibold)
            if let details = DictionaryLabels.details(of: row) {
                Text(details)
                    .font(.system(size: Theme.FontSize.small))
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
        }
        .frame(width: width, alignment: .leading)
    }
}

private extension View {
    /// macOS 26 dims a scroll view's top edge under the title bar; here the
    /// title bar is our own header, which must stay as designed.
    @ViewBuilder
    func hidingTitleBarEdgeEffect() -> some View {
        if #available(macOS 26.0, *) {
            scrollEdgeEffectHidden(true, for: .top)
        } else {
            self
        }
    }
}
