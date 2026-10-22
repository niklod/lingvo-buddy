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

extension ButtonStyle where Self == ThemeButtonStyle {
    /// The card buttons with a minimum width, so short titles ("Continue") do not look cramped.
    static func onboarding(_ kind: ThemeButtonStyle.Kind = .primary) -> ThemeButtonStyle {
        .theme(kind, height: OnboardingLayout.buttonHeight, horizontalPadding: 14, minWidth: 80)
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
