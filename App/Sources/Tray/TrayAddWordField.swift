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
                .font(.system(size: Theme.FontSize.body))
                .foregroundStyle(Theme.Palette.textPrimary)
                .insetField(height: Self.height)
                .onSubmit(submit)
                Button(action: submit) {
                    Image(systemName: "plus")
                        .frame(width: Self.height)
                }
                .buttonStyle(.theme(height: Self.height, horizontalPadding: 0))
                .accessibilityLabel(Text("Add"))
            }
        }
    }

    private func submit() {
        onSubmit(text)
    }
}
