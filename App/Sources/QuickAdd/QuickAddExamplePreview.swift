import SwiftUI

/// The dictionary example and its Russian translation, as the card shows them after the answer.
struct DictionaryExample: Equatable {
    let english: String
    let russian: String?
}

extension QuickAddModel {
    /// The dictionary example of the selected word, which the card gets if "Where I saw it" stays empty.
    /// Own text replaces it on the card, so the preview hides as soon as the
    /// learner types; blank text still gives the dictionary example, so it does not.
    var examplePreview: DictionaryExample? {
        guard example.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let english = candidate?.example else { return nil }
        return DictionaryExample(english: english, russian: candidate?.russianExample)
    }
}

/// The read-only dictionary example under "Where I saw it".
struct ExamplePreview: View {
    let example: DictionaryExample

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Dictionary example")
                .font(.system(size: Theme.FontSize.small))
                .foregroundStyle(Theme.Palette.textSecondary)
            Text(verbatim: example.english)
                .font(.system(size: Theme.FontSize.body).italic())
                .foregroundStyle(Theme.Palette.textBody)
                .fixedSize(horizontal: false, vertical: true)
            if let russian = example.russian {
                Text(verbatim: russian)
                    .font(.system(size: Theme.FontSize.body))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Theme.Palette.raised, in: RoundedRectangle(cornerRadius: Theme.Radius.button))
        .accessibilityElement(children: .combine)
    }
}
