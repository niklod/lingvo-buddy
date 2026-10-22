import SwiftUI

extension QuickAddModel {
    /// The dictionary example of the selected word, which the card gets if "Where I saw it" stays empty.
    /// Own text replaces it on the card, so the preview hides as soon as the
    /// learner types; blank text still gives the dictionary example, so it does not.
    var examplePreview: String? {
        guard example.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return candidate?.example
    }
}

/// The read-only dictionary example under "Where I saw it".
struct ExamplePreview: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Dictionary example")
                .font(.system(size: Theme.FontSize.small))
                .foregroundStyle(Theme.Palette.textSecondary)
            Text(verbatim: text)
                .font(.system(size: Theme.FontSize.body).italic())
                .foregroundStyle(Theme.Palette.textBody)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Theme.Palette.raised, in: RoundedRectangle(cornerRadius: Theme.Radius.button))
        .accessibilityElement(children: .combine)
    }
}
