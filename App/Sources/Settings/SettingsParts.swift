import SwiftUI

/// Settings are not designed; these parts reuse the Dictionary window tokens
/// (window #1E1E20, sidebar #1A1A1C, border #3A3A3C, 13 pt text).
enum SettingsLayout {
    static let width: CGFloat = 520
    static let padding: CGFloat = 20
    static let sectionSpacing: CGFloat = 16
    static let rowSpacing: CGFloat = 10
    static let sectionRadius: CGFloat = 10
    static let sectionBackground = Color(hex: 0x1A1A1C)
}

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(Theme.Palette.textSecondary)
                .padding(.leading, 4)
            VStack(alignment: .leading, spacing: SettingsLayout.rowSpacing) {
                content
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SettingsLayout.sectionBackground, in: RoundedRectangle(cornerRadius: SettingsLayout.sectionRadius))
            .overlay(
                RoundedRectangle(cornerRadius: SettingsLayout.sectionRadius)
                    .strokeBorder(Theme.Palette.border, lineWidth: 1)
            )
        }
    }
}

/// A label on the left, its control on the right, an optional hint below.
struct SettingsRow<Control: View>: View {
    let label: String
    var hint: String?
    @ViewBuilder let control: Control

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .center, spacing: 12) {
                Text(label)
                    .font(.system(size: Theme.FontSize.body))
                    .foregroundStyle(Theme.Palette.textPrimary)
                Spacer(minLength: 8)
                control
            }
            if let hint {
                Text(hint)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct SettingsDivider: View {
    var body: some View {
        Rectangle().fill(Theme.Palette.hairline).frame(height: 1)
    }
}

/// A stepper with its value printed next to it ("Every 15 min").
struct ValueStepper: View {
    let text: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int

    var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.system(size: Theme.FontSize.body).monospacedDigit())
                .foregroundStyle(Theme.Palette.textBody)
            Stepper("", value: $value, in: range, step: step)
                .labelsHidden()
        }
    }
}
