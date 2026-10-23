import LingvoCore
import SwiftUI

/// The "Edit translation" sheet of a Dictionary row. It is a sheet and not an alert: an alert
/// cannot show a hint under its field or disable its Save button.
struct TranslationEditSheet: View {
    let row: WordRow
    let onSave: (String) -> Void
    @State private var text: String
    @Environment(\.dismiss) private var dismiss

    init(row: WordRow, onSave: @escaping (String) -> Void) {
        self.row = row
        self.onSave = onSave
        _text = State(initialValue: row.translation)
    }

    /// Recomputed on every keystroke, so the hint and Save follow the field at once.
    private var problem: LingvoCoreError? { TranslationEditInput.problem(in: text) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Edit translation")
                .font(.system(size: Theme.FontSize.body, weight: .semibold))
            Text(row.headword)
                .foregroundStyle(Theme.Palette.textSecondary)
            TextField(text: $text) { Text("Translation") }
            if let problem {
                Text(verbatim: problem.localizedDescription)
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundStyle(Theme.Palette.wrongText)
            }
            HStack(spacing: 8) {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.theme(.secondary))
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    onSave(text)
                    dismiss()
                }
                .buttonStyle(.theme())
                .keyboardShortcut(.defaultAction)
                .disabled(problem != nil)
            }
        }
        .padding(20)
        .frame(width: 340)
    }
}
