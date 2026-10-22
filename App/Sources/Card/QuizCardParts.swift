import LingvoCore
import SwiftUI

struct QuizCardHeader: View {
    let state: QuizCardState
    let later: () -> Void
    let close: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                KindBadge(kind: state.card.kind, label: state.kindLabel)
                Text(verbatim: state.sourceLabel)
                    .foregroundStyle(Theme.Palette.textSecondary)
                Text(verbatim: state.directionLabel)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.Palette.textBody)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 6)
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.chip).strokeBorder(Theme.Palette.border))
            }
            .font(.system(size: Theme.FontSize.caption))
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                Button(action: later) {
                    Text("Later")
                        .font(.system(size: Theme.FontSize.caption))
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .contentShape(Rectangle())
                }
                Button(action: close) {
                    CloseGlyph()
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(Text("Close"))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.Palette.textSecondary)
        }
    }
}

private struct KindBadge: View {
    let kind: CardKind
    let label: LocalizedStringKey

    var body: some View {
        Text(label)
            .fontWeight(.semibold)
            .foregroundStyle(colors.foreground)
            .padding(.vertical, 2)
            .padding(.horizontal, 8)
            .background(colors.background, in: RoundedRectangle(cornerRadius: Theme.Radius.chip))
    }

    private var colors: (background: Color, foreground: Color) {
        switch kind {
        case .new: (Color(hex: 0x0A84FF).opacity(0.18), Color(hex: 0x64D2FF))
        case .review: (Color(hex: 0x5E5CE6).opacity(0.22), Color(hex: 0xB7B5FF))
        case .mine: (Color(hex: 0xFF9F0A).opacity(0.18), Color(hex: 0xFFC56B))
        }
    }
}

/// The 12×12 "×" from the design (two 1.6 pt round-capped strokes).
private struct CloseGlyph: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 2, y: 2))
            path.addLine(to: CGPoint(x: 10, y: 10))
            path.move(to: CGPoint(x: 10, y: 2))
            path.addLine(to: CGPoint(x: 2, y: 10))
        }
        .stroke(style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        .frame(width: 12, height: 12)
    }
}

struct QuizOptionButton: View {
    private static let minHeight: CGFloat = 48
    private static let maxLines = 3
    private static let verticalPadding: CGFloat = 6
    private static let compactFontSize: CGFloat = 13

    let key: Int
    let text: String
    let appearance: OptionAppearance
    let action: () -> Void

    private func label(size: CGFloat, lines: Int) -> some View {
        Text(verbatim: text)
            .font(.system(size: size))
            .foregroundStyle(Theme.Palette.textPrimary)
            .multilineTextAlignment(.leading)
            .lineLimit(lines)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(verbatim: "\(key)")
                    .font(.system(size: Theme.FontSize.keyBadge))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .frame(width: 20, height: 20)
                    .background(Theme.Palette.keyBadge, in: RoundedRectangle(cornerRadius: Theme.Radius.keyBadge))
                // Some answers are long ("средства массовой информации"): a cut-off
                // option could hide the right answer. One line first, like the design;
                // a slightly smaller line next; wrapped lines only when neither fits.
                ViewThatFits(in: .horizontal) {
                    label(size: Theme.FontSize.option, lines: 1)
                    label(size: Self.compactFontSize, lines: 1)
                    label(size: Theme.FontSize.option, lines: Self.maxLines)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, Self.verticalPadding)
            // Both options of a grid row take the taller one's height.
            .frame(minHeight: Self.minHeight, maxHeight: .infinity)
            .background(fill, in: RoundedRectangle(cornerRadius: Theme.Radius.option))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.option).strokeBorder(stroke, lineWidth: 1))
            .opacity(appearance == .faded ? 0.45 : 1)
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.option))
        }
        .buttonStyle(.plain)
    }

    private var fill: Color {
        switch appearance {
        case .idle, .faded: Theme.Palette.raised
        case .correct: Theme.Palette.success.opacity(0.16)
        case .pickedWrong: Theme.Palette.wrong.opacity(0.16)
        }
    }

    private var stroke: Color {
        switch appearance {
        case .idle: Theme.Palette.border
        case .faded: Theme.Palette.raised
        case .correct: Theme.Palette.success
        case .pickedWrong: Theme.Palette.wrong
        }
    }
}

struct QuizCardFooter: View {
    let state: QuizCardState
    let next: () -> Void
    let dontKnow: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                MasteryDots(filled: state.mastery)
                Text(verbatim: state.masteryLabel)
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            Spacer(minLength: 0)
            if state.isAnswered {
                Button(action: next) {
                    Text("Next ↵")
                        .font(.system(size: Theme.FontSize.body, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 32)
                        .background(Theme.Palette.accent, in: RoundedRectangle(cornerRadius: Theme.Radius.button))
                }
                .buttonStyle(.plain)
            } else {
                Button(action: dontKnow) {
                    Text("Don't know")
                        .font(.system(size: Theme.FontSize.body))
                        .foregroundStyle(Theme.Palette.textBody)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.button).strokeBorder(Theme.Palette.border))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct MasteryDots: View {
    static let total = 4
    let filled: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<Self.total, id: \.self) { index in
                Circle()
                    .fill(index < filled ? Theme.Palette.accent : Theme.Palette.border)
                    .frame(width: 8, height: 8)
            }
        }
    }
}
