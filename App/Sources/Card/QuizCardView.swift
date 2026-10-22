import LingvoCore
import SwiftUI

struct QuizCardActions {
    var pick: (Int) -> Void = { _ in }
    var dontKnow: () -> Void = {}
    var next: () -> Void = {}
    var later: () -> Void = {}
    var close: () -> Void = {}
}

/// The quiz card from the design: header, word, 2×2 options, feedback with Kapa's mood, footer.
struct QuizCardView: View {
    static let width: CGFloat = 380

    let state: QuizCardState
    var actions = QuizCardActions()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            QuizCardHeader(state: state, later: actions.later, close: actions.close)
            wordBlock
            optionsGrid
            if let feedback = state.feedbackText {
                feedbackBlock(feedback)
            }
            QuizCardFooter(state: state, next: actions.next, dontKnow: actions.dontKnow)
        }
        .padding(18)
        .frame(width: Self.width)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Theme.Palette.panel)
                .shadow(color: Theme.Palette.shadow, radius: Theme.CardShadow.radius, y: Theme.CardShadow.offsetY)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.Palette.hairline, lineWidth: 1)
        )
        .padding(Theme.CardShadow.insets)
        .environment(\.colorScheme, .dark)
    }

    private var wordBlock: some View {
        VStack(spacing: 4) {
            Text(verbatim: state.card.prompt)
                .font(.system(size: Theme.FontSize.word, weight: .bold))
                .tracking(-0.5)
                .foregroundStyle(Theme.Palette.textStrong)
            Text(verbatim: state.subtitle)
                .font(.system(size: Theme.FontSize.body))
                .foregroundStyle(Theme.Palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    private var optionsGrid: some View {
        let rows = stride(from: 0, to: state.card.options.count, by: 2).map { start in
            Array(start..<min(start + 2, state.card.options.count))
        }
        return Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(rows, id: \.self) { row in
                GridRow {
                    ForEach(row, id: \.self) { index in
                        QuizOptionButton(
                            key: index + 1,
                            text: state.card.options[index],
                            appearance: state.appearance(ofOption: index),
                            action: { actions.pick(index) }
                        )
                        // Not `.disabled`: that would dim the green and orange result states.
                        .allowsHitTesting(!state.isAnswered)
                    }
                }
            }
        }
    }

    private func feedbackBlock(_ text: String) -> some View {
        HStack(spacing: 12) {
            if let answer = state.answer {
                KapaMoodView(mood: KapaMood(answer.result))
            }
            feedbackText(text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Theme.Palette.raised, in: RoundedRectangle(cornerRadius: Theme.Radius.option))
    }

    private func feedbackText(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: text)
                .font(.system(size: Theme.FontSize.body, weight: .semibold))
                .foregroundStyle(state.feedbackIsPositive ? Theme.Palette.success : Theme.Palette.wrongText)
            if let example = state.card.example {
                Text(verbatim: example)
                    .font(.system(size: Theme.FontSize.body).italic())
                    .foregroundStyle(Theme.Palette.textBody)
            }
            if let russianExample = state.russianExample {
                Text(verbatim: russianExample)
                    .font(.system(size: Theme.FontSize.body))
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            if let url = state.youGlishURL {
                Link(destination: url) {
                    Text(verbatim: state.youGlishLabel)
                        .font(.system(size: Theme.FontSize.caption, weight: .medium))
                        .foregroundStyle(Theme.Palette.link)
                }
                .buttonStyle(.plain)
                .pointerStyle(.link)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
