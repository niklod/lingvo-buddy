import LingvoCore
import Observation

/// Which translation goes on the card.
enum TranslationChoice: Equatable {
    /// Index into the dictionary translations.
    case dictionary(Int)
    /// The "+ custom variant" text.
    case custom
}

/// A line the footer shows instead of the default hint.
enum QuickAddMessage: Equatable {
    case standing(WordStanding)
    case error(String)
}

/// The live state of the quick-add panel. The view binds to it; the lookup
/// runs on every edit of the word, which is cheap (one indexed SQLite read).
@MainActor
@Observable
final class QuickAddModel {
    var text: String {
        didSet { if text != oldValue { refreshPreview() } }
    }
    var choice: TranslationChoice = .custom
    var customTranslation = ""
    var example = ""
    private(set) var preview: QuickAddPreview?
    private(set) var message: QuickAddMessage?

    @ObservationIgnored private let lookup: (String) throws -> QuickAddPreview?

    init(text: String = "", example: String = "", lookup: @escaping (String) throws -> QuickAddPreview?) {
        self.text = text
        self.example = example
        self.lookup = lookup
        refreshPreview()
    }

    var translations: [String] {
        preview?.lookup?.entry.translations[.russian] ?? []
    }

    /// Words the dictionary lacks always need the custom field.
    var showsCustomField: Bool {
        choice == .custom || (preview != nil && translations.isEmpty)
    }

    var chosenTranslation: String {
        switch choice {
        case .dictionary(let index) where translations.indices.contains(index): translations[index]
        case .dictionary, .custom: customTranslation
        }
    }

    var canSubmit: Bool {
        guard let preview, preview.canAdd else { return false }
        return !chosenTranslation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func choose(_ choice: TranslationChoice) {
        self.choice = choice
        if message.isError { message = nil }
    }

    /// The word to add, or `nil` (with a footer message) when the form is not ready.
    func submission() -> NewMyWord? {
        guard let preview else { return nil }
        guard preview.canAdd else {
            message = .standing(preview.standing)
            return nil
        }
        guard canSubmit else {
            message = .error(String(localized: "Type a translation for the card."))
            return nil
        }
        return NewMyWord(text: preview.headword, translation: chosenTranslation, example: example)
    }

    func show(_ message: QuickAddMessage) {
        self.message = message
    }

    /// The first dictionary translation is preselected for each new word; a
    /// choice made for the same word survives further edits (a trailing space).
    private func refreshPreview() {
        let previousHeadword = preview?.headword
        do {
            preview = try lookup(text)
            message = preview.flatMap { $0.canAdd ? nil : .standing($0.standing) }
        } catch {
            preview = nil
            message = .error(error.localizedDescription)
        }
        if preview?.headword != previousHeadword {
            choice = translations.isEmpty ? .custom : .dictionary(0)
        }
    }
}

private extension Optional where Wrapped == QuickAddMessage {
    var isError: Bool {
        if case .error = self { true } else { false }
    }
}
