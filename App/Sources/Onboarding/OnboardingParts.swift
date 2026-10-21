import SwiftUI

/// Onboarding is not designed; it reuses the card and Settings tokens.
enum OnboardingLayout {
    static let width: CGFloat = 460
    static let padding: CGFloat = 24
    static let spacing: CGFloat = 18
    static let titleSize: CGFloat = 20
    static let buttonHeight: CGFloat = 32
}

/// "Step 2 of 3", the title and a short text.
struct OnboardingHeader: View {
    let step: OnboardingStep
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Step \(step.number) of \(OnboardingStep.count)"))
                .font(.system(size: Theme.FontSize.caption))
                .foregroundStyle(Theme.Palette.textSecondary)
            Text(title)
                .font(.system(size: OnboardingLayout.titleSize, weight: .semibold))
                .foregroundStyle(Theme.Palette.textPrimary)
            Text(text)
                .font(.system(size: Theme.FontSize.body))
                .foregroundStyle(Theme.Palette.textBody)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The card's "Next ↵" (primary) and "Don't know" (secondary) button looks.
struct OnboardingButton: View {
    enum Kind {
        case primary
        case secondary
    }

    let title: String
    var kind: Kind = .primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: Theme.FontSize.body, weight: kind == .primary ? .semibold : .regular))
                .foregroundStyle(kind == .primary ? Theme.Palette.textStrong : Theme.Palette.textBody)
                .padding(.horizontal, 14)
                .frame(minWidth: 80, minHeight: OnboardingLayout.buttonHeight)
                .background(background)
                .overlay(border)
                .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var background: some View {
        if kind == .primary {
            RoundedRectangle(cornerRadius: Theme.Radius.button).fill(Theme.Palette.accent)
        }
    }

    @ViewBuilder private var border: some View {
        if kind == .secondary {
            RoundedRectangle(cornerRadius: Theme.Radius.button).strokeBorder(Theme.Palette.border)
        }
    }
}

/// A quiet text button for "Skip" and "Finish now".
struct OnboardingLinkButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: Theme.FontSize.caption))
                .foregroundStyle(Theme.Palette.textSecondary)
                .frame(minHeight: OnboardingLayout.buttonHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A thin progress line for the level check.
struct OnboardingProgressBar: View {
    let done: Int
    let total: Int

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.Palette.raised)
                Capsule()
                    .fill(Theme.Palette.accent)
                    .frame(width: proxy.size.width * fraction)
            }
        }
        .frame(height: 4)
    }

    private var fraction: CGFloat {
        total > 0 ? CGFloat(done) / CGFloat(total) : 0
    }
}
