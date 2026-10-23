import SwiftUI

struct TrayMenuActions {
    var showWordNow: () -> Void = {}
    var chooseInterval: () -> Void = {}
    var choosePause: () -> Void = {}
    var resume: () -> Void = {}
    var openDictionary: () -> Void = {}
    var openSettings: () -> Void = {}
    var quit: () -> Void = {}
}

enum TrayRow: Hashable {
    case showWordNow, nextCard, pause, dictionary, settings
}

/// The tray menu from the design: header with Kapa, Top‑1000 progress card, add-word
/// slot, menu rows, today's numbers and Quit.
struct TrayMenuView<AddWordField: View>: View {
    static var width: CGFloat { 320 }
    private static var kapaHeight: CGFloat { 30 }

    let state: TrayMenuState
    /// Read in `body`, so the button follows the download while the tray stays open.
    var update = UpdateCenter()
    var actions = TrayMenuActions()
    /// Snapshots show the design's highlighted first row; the app starts with none.
    @State var highlighted: TrayRow?
    @ViewBuilder var addWordField: () -> AddWordField

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            TrayProgressCard(state: state)
            addWordField()
            TrayDivider()
            rows
            TrayDivider()
            footer
            quitButton
        }
        .padding(14)
        .frame(width: Self.width)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.tray)
                .fill(Theme.Palette.panel)
                .shadow(color: Theme.Palette.shadow, radius: Theme.CardShadow.radius, y: Theme.CardShadow.offsetY)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.tray)
                .strokeBorder(Theme.Palette.hairline, lineWidth: 1)
        )
        .padding(Theme.CardShadow.insets)
        .environment(\.colorScheme, .dark)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                KapaMoodView(mood: state.kapaMood, height: Self.kapaHeight)
                Text(verbatim: "LingvoBuddy")
                    .font(.system(size: Theme.FontSize.title, weight: .bold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(1)
                    .fixedSize()
                Spacer(minLength: 4)
                if let button = update.state.button {
                    UpdateButtonView(button: button, action: update.clickInstall)
                }
                // "Restarting…" leaves no room for the streak, and the app quits in seconds.
                if update.state.button?.label != .restarting {
                    Text(verbatim: state.streakLabel)
                        .font(.system(size: Theme.FontSize.caption))
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
            if let reason = update.state.failureReason {
                UpdateFailureLine(reason: reason)
            }
        }
    }

    private var rows: some View {
        VStack(spacing: 2) {
            row(.showWordNow, title: String(localized: "Show word now"), detail: "⌥⌘W", action: actions.showWordNow)
            row(
                .nextCard,
                title: state.nextCardLabel,
                detail: "\(state.intervalLabel) ›",
                action: actions.chooseInterval
            )
            row(
                .pause,
                title: state.pauseLabel,
                detail: state.isPaused ? "" : "›",
                action: state.isPaused ? actions.resume : actions.choosePause
            )
            row(
                .dictionary,
                title: String(localized: "Open Dictionary…"),
                detail: "⌘D",
                action: actions.openDictionary
            )
            row(
                .settings,
                title: String(localized: "Settings…"),
                detail: "⌘,",
                action: actions.openSettings
            )
        }
    }

    private func row(
        _ row: TrayRow,
        title: String,
        detail: String,
        action: @escaping () -> Void
    ) -> some View {
        TrayMenuRow(
            title: title,
            detail: detail,
            isHighlighted: highlighted == row,
            action: action
        )
        .onHover { hovering in
            if hovering {
                highlighted = row
            } else if highlighted == row {
                highlighted = nil
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: state.todayLabel)
            Text(verbatim: state.reviewsLabel)
        }
        .font(.system(size: Theme.FontSize.caption))
        .foregroundStyle(Theme.Palette.textSecondary)
    }

    private var quitButton: some View {
        Button(action: actions.quit) {
            Text("Quit")
                .font(.system(size: Theme.FontSize.body))
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
