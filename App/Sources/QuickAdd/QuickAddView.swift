import LingvoCore
import SwiftUI

struct QuickAddActions {
    var submit: () -> Void = {}
    var cancel: () -> Void = {}
}

/// The Spotlight-like quick-add panel from the design (`design/src/3_quick_add.html`).
struct QuickAddView: View {
    enum Field: Hashable {
        case word, custom, englishWord, example
    }

    @Bindable var model: QuickAddModel
    var actions = QuickAddActions()
    @FocusState private var focus: Field?

    var body: some View {
        VStack(spacing: 0) {
            header
            VStack(alignment: .leading, spacing: 12) {
                if !model.metaLine.isEmpty {
                    Text(verbatim: model.metaLine)
                        .font(.system(size: Theme.FontSize.caption))
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                if let note = model.missingTranslationNote {
                    Text(verbatim: note)
                        .font(.system(size: Theme.FontSize.caption))
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                if model.needsEnglishWord {
                    englishWordSection
                } else if model.isRussianInput {
                    candidateSection
                } else if model.preview != nil {
                    translationSection
                }
                section(String(localized: "Where I saw it (optional)")) {
                    QuickAddField(placeholder: "", text: $model.example, italic: true)
                        .focused($focus, equals: .example)
                    if let example = model.examplePreview {
                        ExamplePreview(example: example)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            footer
        }
        .frame(width: QuickAddTheme.width)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.card).fill(Theme.Palette.panel))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Theme.Palette.hairline, lineWidth: 1))
        .compositingGroup()
        .shadow(color: Theme.Palette.shadow, radius: Theme.CardShadow.radius, y: Theme.CardShadow.offsetY)
        .padding(Theme.CardShadow.insets)
        .environment(\.colorScheme, .dark)
        .onAppear { focus = .word }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus")
                .font(.system(size: 17, weight: .light))
                .foregroundStyle(Theme.Palette.textSecondary)
                .frame(width: 18, height: 18)
            TextField(text: $model.text, prompt: Text("Word").foregroundStyle(Theme.Palette.textSecondary)) {
                Text("Word")
            }
            .textFieldStyle(.plain)
            .font(.system(size: QuickAddTheme.wordFontSize, weight: .semibold))
            .foregroundStyle(Theme.Palette.textStrong)
            .focused($focus, equals: .word)
            Text(verbatim: model.directionLabel)
                .font(.system(size: Theme.FontSize.caption))
                .foregroundStyle(Theme.Palette.textSecondary)
        }
        .padding(.horizontal, 16)
        .frame(height: QuickAddTheme.headerHeight)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.Palette.border).frame(height: 1) }
    }

    private var translationSection: some View {
        section(String(localized: "Translation for the card")) {
            if !model.translations.isEmpty || model.machineBubble != nil {
                FlowLayout(spacing: 6) {
                    ForEach(Array(model.translations.enumerated()), id: \.offset) { index, translation in
                        TranslationPill(title: translation, isSelected: model.choice == .dictionary(index)) {
                            model.choose(.dictionary(index))
                        }
                    }
                    machinePill
                    customPill(focusing: .custom)
                }
            }
            if model.showsCustomField {
                QuickAddField(placeholder: String(localized: "Your translation"), text: $model.customTranslation)
                    .focused($focus, equals: .custom)
                MachineSuggestionNote(machine: model.machine) { model.downloadLanguagePack() }
            }
            if let hint = model.definitionHint {
                Text(verbatim: hint)
                    .font(.system(size: Theme.FontSize.small))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Russian text the dictionary does not know: the typed text is the translation.
    private var englishWordSection: some View {
        section(String(localized: "English word for the card")) {
            if model.machineBubble != nil {
                FlowLayout(spacing: 6) {
                    machinePill
                    customPill(focusing: .englishWord)
                }
            }
            if model.showsEnglishWordField {
                QuickAddField(placeholder: String(localized: "English word"), text: $model.englishWord)
                    .focused($focus, equals: .englishWord)
                MachineSuggestionNote(machine: model.machine) { model.downloadLanguagePack() }
            }
        }
    }

    @ViewBuilder private var machinePill: some View {
        if let bubble = model.machineBubble {
            TranslationPill(
                title: bubble,
                isSelected: model.choice == .machine,
                mark: String(localized: "machine translation")
            ) {
                model.choose(.machine)
            }
        }
    }

    private func customPill(focusing field: Field) -> some View {
        TranslationPill(
            title: String(localized: "+ custom variant"),
            isSelected: model.choice == .custom,
            isCustom: true
        ) {
            model.choose(.custom)
            focus = field
        }
    }

    private var candidateSection: some View {
        section(String(localized: "English word for the card")) {
            FlowLayout(spacing: 6) {
                ForEach(Array(model.candidates.enumerated()), id: \.offset) { index, candidate in
                    TranslationPill(title: candidate.headword, isSelected: model.candidateIndex == index) {
                        model.chooseCandidate(index)
                    }
                }
            }
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: title)
                .font(.system(size: Theme.FontSize.caption))
                .foregroundStyle(Theme.Palette.textSecondary)
            content()
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Text(verbatim: model.footerText)
                .font(.system(size: Theme.FontSize.caption))
                .foregroundStyle(model.footerIsWarning ? Theme.Palette.wrongText : Theme.Palette.textSecondary)
                .lineLimit(2)
            Spacer(minLength: 8)
            Button(action: actions.cancel) { Text(verbatim: "Esc") }
                .buttonStyle(.footer(.secondary))
            Button(String(localized: "Add ↵"), action: actions.submit)
                .buttonStyle(.footer(.primary))
                .disabled(!model.canSubmit)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(QuickAddTheme.footerBackground)
        .overlay(alignment: .top) { Rectangle().fill(Theme.Palette.border).frame(height: 1) }
    }
}
