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
/// reads the dictionary and all progress, so it waits for a short pause in typing.
@MainActor
@Observable
final class QuickAddModel {
    private static let lookupDelay: Duration = .milliseconds(80)

    var text: String {
        didSet { if text != oldValue { scheduleLookup() } }
    }
    var choice: TranslationChoice = .custom
    var customTranslation = ""
    var example = ""
    private(set) var preview: QuickAddPreview?
    private(set) var message: QuickAddMessage?
    /// Index into `preview.candidates`: the English word for Russian input.
    private(set) var candidateIndex = 0

    @ObservationIgnored private let lookup: (String) throws -> QuickAddPreview?
    @ObservationIgnored private var pendingLookup: Task<Void, Never>?

    init(text: String = "", example: String = "", lookup: @escaping (String) throws -> QuickAddPreview?) {
        self.text = text
        self.example = example
        self.lookup = lookup
        refreshPreview()
    }

    /// The word the footer, the meta line and "Add" refer to.
    var candidate: QuickAddCandidate? {
        guard let candidates = preview?.candidates, candidates.indices.contains(candidateIndex) else {
            return preview?.candidates.first
        }
        return candidates[candidateIndex]
    }

    /// The English words to choose from; empty for English input.
    var candidates: [QuickAddCandidate] {
        isRussianInput ? preview?.candidates ?? [] : []
    }

    /// The typed Russian word is the translation, so there is none to choose.
    var isRussianInput: Bool { preview?.russianText != nil }

    var translations: [String] {
        guard !isRussianInput else { return [] }
        return candidate?.lookup?.entry.translations[.russian] ?? []
    }

    /// Words the dictionary lacks always need the custom field.
    var showsCustomField: Bool {
        guard !isRussianInput else { return false }
        return choice == .custom || (preview != nil && translations.isEmpty)
    }

    var chosenTranslation: String {
        if let russianText = preview?.russianText { return russianText }
        return switch choice {
        case .dictionary(let index) where translations.indices.contains(index): translations[index]
        case .dictionary, .custom: customTranslation
        }
    }

    var canSubmit: Bool {
        guard let candidate, candidate.canAdd else { return false }
        return !chosenTranslation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func choose(_ choice: TranslationChoice) {
        self.choice = choice
        if message.isError { message = nil }
    }

    func chooseCandidate(_ index: Int) {
        guard candidates.indices.contains(index) else { return }
        candidateIndex = index
        message = Self.standingMessage(for: candidate)
    }

    /// `false` when there is nothing to move through, so the key keeps its text-field meaning.
    func moveCandidate(by offset: Int) -> Bool {
        guard candidates.count > 1 else { return false }
        chooseCandidate(min(max(candidateIndex + offset, 0), candidates.count - 1))
        return true
    }

    /// The word to add, or `nil` (with a footer message) when the form is not ready.
    func submission() -> NewMyWord? {
        // Enter can come before the typing pause ends; the word must be the one on screen.
        if pendingLookup != nil {
            refreshPreview()
        }
        guard let candidate else { return nil }
        guard candidate.canAdd else {
            message = .standing(candidate.standing)
            return nil
        }
        guard canSubmit else {
            message = .error(String(localized: "Type a translation for the card."))
            return nil
        }
        return NewMyWord(text: candidate.headword, translation: chosenTranslation, example: example)
    }

    func show(_ message: QuickAddMessage) {
        self.message = message
    }

    /// The first dictionary translation and the first candidate are preselected
    /// for each new word; a choice made for the same word survives further edits
    /// (a trailing space).
    private func scheduleLookup() {
        pendingLookup?.cancel()
        pendingLookup = Task { [weak self] in
            try? await Task.sleep(for: Self.lookupDelay)
            guard !Task.isCancelled else { return }
            self?.refreshPreview()
        }
    }

    private func refreshPreview() {
        pendingLookup?.cancel()
        pendingLookup = nil
        let previousWord = preview?.typedWord
        var failure: QuickAddMessage?
        do {
            preview = try lookup(text)
        } catch {
            preview = nil
            failure = .error(error.localizedDescription)
        }
        if preview?.typedWord != previousWord {
            candidateIndex = 0
            choice = translations.isEmpty ? .custom : .dictionary(0)
        }
        message = failure ?? Self.standingMessage(for: candidate)
    }

    private static func standingMessage(for candidate: QuickAddCandidate?) -> QuickAddMessage? {
        candidate.flatMap { $0.canAdd ? nil : .standing($0.standing) }
    }
}

private extension QuickAddPreview {
    /// The dictionary headword for English input (so "Reluctant" and "reluctant"
    /// keep the choice), the trimmed text for Russian input.
    var typedWord: String { russianText ?? headword }
}

private extension Optional where Wrapped == QuickAddMessage {
    var isError: Bool {
        if case .error = self { true } else { false }
    }
}
