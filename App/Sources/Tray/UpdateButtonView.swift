import LingvoCore
import SwiftUI

/// The pill in the tray header from the "Auto update · tray header flow" board.
struct UpdateButtonView: View {
    private static let height: CGFloat = 22
    private static let iconSize: CGFloat = 12

    let button: UpdateButton
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                icon.frame(width: Self.iconSize, height: Self.iconSize)
                Text(verbatim: text)
            }
            .font(.system(size: Theme.FontSize.small, weight: .semibold))
            .foregroundStyle(style.text)
            .padding(.horizontal, 7)
            .frame(height: Self.height)
            .background(style.fill, in: Capsule())
            .overlay(Capsule().strokeBorder(style.border, lineWidth: 1))
            .contentShape(Capsule())
            .fixedSize()
        }
        .buttonStyle(PillButtonStyle())
        // `disabled`, not `allowsHitTesting`: VoiceOver must not press a running download either.
        .disabled(!button.acceptsClicks)
        .help(button.acceptsClicks ? tooltip : "")
        .accessibilityLabel(tooltip)
    }

    private var tooltip: String {
        String(localized: "Update to \(button.version) — download and restart")
    }

    private var text: String {
        switch button.label {
        case .version: button.version
        case .percent(let percent): "\(percent)%"
        case .restarting: String(localized: "Restarting…")
        case .retry: String(localized: "Retry")
        }
    }

    @ViewBuilder private var icon: some View {
        switch button.label {
        case .version: UpdateGlyph(kind: .download)
        case .retry: UpdateGlyph(kind: .retry)
        case .restarting: UpdateGlyph(kind: .restarting)
        case .percent(let percent): UpdateProgressRing(fraction: Double(percent) / 100)
        }
    }

    private struct Style {
        let fill: Color
        let border: Color
        let text: Color
    }

    private var style: Style {
        switch button.label {
        case .version:
            Style(fill: Theme.Palette.accent.opacity(0.18), border: Theme.Palette.accent, text: Theme.Palette.link)
        case .retry:
            Style(fill: Theme.Palette.wrong.opacity(0.16), border: Theme.Palette.wrong, text: Theme.Palette.wrongText)
        case .percent:
            Style(fill: Theme.Palette.raised, border: Theme.Palette.border, text: Theme.Palette.textBody)
        case .restarting:
            Style(fill: Theme.Palette.raised, border: Theme.Palette.border, text: Theme.Palette.textSecondary)
        }
    }
}

/// Draws the label as it is, so a disabled pill keeps the board's colours.
private struct PillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

struct UpdateFailureLine: View {
    let reason: UpdateFailureReason

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: Theme.FontSize.small))
            .foregroundStyle(Theme.Palette.wrongText)
    }

    private var text: String {
        switch reason {
        case .noConnection: String(localized: "Update failed: no connection. Try again later.")
        case .verificationFailed: String(localized: "The download is damaged. Try again later.")
        case .other: String(localized: "Update failed. Try again later.")
        }
    }
}

/// The 12 × 12 icons of the board, drawn in the board's 12-point box.
private struct UpdateGlyph: View {
    enum Kind { case download, retry, restarting }

    private static let stroke = StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)

    let kind: Kind

    var body: some View {
        Canvas { context, size in
            let scale = size.width / 12
            context.stroke(
                path.applying(.init(scaleX: scale, y: scale)),
                with: .foreground,
                style: Self.stroke
            )
        }
    }

    private var path: Path {
        var path = Path()
        switch kind {
        case .download:
            path.move(to: CGPoint(x: 6, y: 1.5))
            path.addLine(to: CGPoint(x: 6, y: 7.5))
            path.move(to: CGPoint(x: 3.5, y: 5))
            path.addLine(to: CGPoint(x: 6, y: 7.5))
            path.addLine(to: CGPoint(x: 8.5, y: 5))
            path.move(to: CGPoint(x: 2, y: 10.5))
            path.addLine(to: CGPoint(x: 10, y: 10.5))
        case .retry:
            // SwiftUI's `clockwise: false` runs clockwise on screen (y points down).
            path.addArc(
                center: CGPoint(x: 6, y: 6), radius: 4,
                startAngle: .degrees(0), endAngle: .degrees(-45), clockwise: false
            )
            path.move(to: CGPoint(x: 10, y: 1.8))
            path.addLine(to: CGPoint(x: 10, y: 4.2))
            path.addLine(to: CGPoint(x: 7.6, y: 4.2))
        case .restarting:
            path.addArc(
                center: CGPoint(x: 6, y: 6), radius: 4.5,
                startAngle: .degrees(-90), endAngle: .degrees(180), clockwise: false
            )
        }
        return path
    }
}

private struct UpdateProgressRing: View {
    let fraction: Double

    var body: some View {
        ZStack {
            Circle().stroke(Theme.Palette.border, lineWidth: 1.8)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(Theme.Palette.link, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(0.75)
    }
}
