import SwiftUI

/// The tray's inline "Add word" field. Enter or "+" hands the text to quick
/// add, which opens prefilled; the tray itself adds nothing.
struct TrayAddWordField: View {
    private static let height: CGFloat = 32

    let onSubmit: (String) -> Void
    @State var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Add word")
                .font(.system(size: Theme.FontSize.caption))
                .foregroundStyle(Theme.Palette.textSecondary)
            HStack(spacing: 6) {
                TextField(
                    text: $text,
                    prompt: Text("For example, reluctant").foregroundStyle(Theme.Palette.textSecondary)
                ) {
                    Text("Add word")
                }
                .textFieldStyle(.plain)
                .font(.system(size: Theme.FontSize.body))
                .foregroundStyle(Theme.Palette.textPrimary)
                .padding(.horizontal, 10)
                .frame(height: Self.height)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.button).fill(QuickAddTheme.fieldBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.button).strokeBorder(Theme.Palette.border, lineWidth: 1)
                )
                .onSubmit(submit)
                Button(action: submit) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textStrong)
                        .frame(width: Self.height, height: Self.height)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.button).fill(Theme.Palette.accent))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Add"))
            }
        }
    }

    private func submit() {
        onSubmit(text)
    }
}
