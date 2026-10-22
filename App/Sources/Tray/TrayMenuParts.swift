import SwiftUI

/// The raised card with learned / total, the bar, and three counts.
struct TrayProgressCard: View {
    let state: TrayMenuState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(verbatim: state.topTierTitle)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Spacer(minLength: 8)
                Text(verbatim: state.learnedLabel)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            .font(.system(size: Theme.FontSize.body))
            TrayProgressBar(fraction: state.learnedFraction)
            HStack(alignment: .top, spacing: 8) {
                TrayCount(value: String(state.stats.learningCount), label: String(localized: "learning"))
                TrayCount(value: String(state.stats.myWordsCount), label: String(localized: "my words"))
                TrayCount(value: state.accuracyValue, label: String(localized: "accuracy"))
            }
            .padding(.top, 4)
        }
        .padding(12)
        .background(Theme.Palette.raised, in: RoundedRectangle(cornerRadius: Theme.Radius.option))
    }
}

private struct TrayProgressBar: View {
    private static let height: CGFloat = 6

    let fraction: Double

    var body: some View {
        Capsule()
            .fill(Theme.Palette.border)
            .frame(height: Self.height)
            .overlay(alignment: .leading) {
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Theme.Palette.accent)
                        .frame(width: geometry.size.width * fraction)
                }
            }
            .clipShape(Capsule())
    }
}

private struct TrayCount: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: value)
                .font(.system(size: Theme.FontSize.stat, weight: .bold))
                .foregroundStyle(Theme.Palette.textPrimary)
            Text(verbatim: label)
                .font(.system(size: Theme.FontSize.small))
                .foregroundStyle(Theme.Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TrayDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.Palette.border)
            .frame(height: 1)
    }
}

/// One menu row: title on the left, shortcut or "›" on the right; blue while hovered.
struct TrayMenuRow: View {
    private static let height: CGFloat = 34

    let title: String
    let detail: String
    let isHighlighted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(verbatim: title)
                    .foregroundStyle(isHighlighted ? Theme.Palette.textStrong : Theme.Palette.textPrimary)
                Spacer(minLength: 8)
                Text(verbatim: detail)
                    .foregroundStyle(isHighlighted ? Theme.Palette.textStrong : Theme.Palette.textSecondary)
            }
            .font(.system(size: Theme.FontSize.body))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .frame(height: Self.height)
            .background(
                isHighlighted ? Theme.Palette.accent : Color.clear,
                in: RoundedRectangle(cornerRadius: Theme.Radius.chip)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
