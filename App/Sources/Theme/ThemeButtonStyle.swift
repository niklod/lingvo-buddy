import SwiftUI

/// The design's two text buttons: the filled accent "primary" ("Next ↵", "Add ↵",
/// "+ Word") and the outlined "secondary" ("Don't know", "Esc"). Only the size
/// changes between places, so the look lives here once.
struct ThemeButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
    }

    /// The look the quick-add "Add ↵" had: its own 0.45 fade, halved again by `.plain`.
    private static let disabledOpacity = 0.225
    /// `.plain` dims a pressed label; a custom style must do it itself.
    private static let pressedOpacity = 0.75

    let kind: Kind
    let height: CGFloat
    let radius: CGFloat
    let horizontalPadding: CGFloat?
    let minWidth: CGFloat?
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: Theme.FontSize.body, weight: kind == .primary ? .semibold : .regular))
            .foregroundStyle(kind == .primary ? Theme.Palette.textStrong : Theme.Palette.textBody)
            .padding(.horizontal, horizontalPadding ?? (kind == .primary ? 14 : 12))
            .frame(minWidth: minWidth)
            .frame(height: height)
            .background(background)
            .overlay(border)
            .contentShape(Rectangle())
            .opacity((isEnabled ? 1 : Self.disabledOpacity) * (configuration.isPressed ? Self.pressedOpacity : 1))
    }

    @ViewBuilder private var background: some View {
        if kind == .primary {
            RoundedRectangle(cornerRadius: radius).fill(Theme.Palette.accent)
        }
    }

    @ViewBuilder private var border: some View {
        if kind == .secondary {
            RoundedRectangle(cornerRadius: radius).strokeBorder(Theme.Palette.border, lineWidth: 1)
        }
    }
}

extension ButtonStyle where Self == ThemeButtonStyle {
    /// `horizontalPadding` defaults to 14 (primary) or 12 (secondary), as in the design.
    static func theme(
        _ kind: ThemeButtonStyle.Kind = .primary,
        height: CGFloat = 32,
        radius: CGFloat = Theme.Radius.button,
        horizontalPadding: CGFloat? = nil,
        minWidth: CGFloat? = nil
    ) -> ThemeButtonStyle {
        ThemeButtonStyle(
            kind: kind,
            height: height,
            radius: radius,
            horizontalPadding: horizontalPadding,
            minWidth: minWidth
        )
    }
}
