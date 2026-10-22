import LingvoCore
import Observation

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
    static let lookupDelay: Duration = .milliseconds(80)

    var text: String {
        didSet {
            guard text != oldValue else { return }
            cancelWaitingTranslation()
            scheduleLookup()
        }
    }
    var choice: TranslationChoice = .custom
    var customTranslation = ""
    /// The card's English word for Russian text the dictionary does not know.
    var englishWord = "" {
        didSet {
            guard englishWord != oldValue else { return }
            syncDetails(delayed: true)
        }
    }
    var example = ""
    private(set) var preview: QuickAddPreview?
    private(set) var message: QuickAddMessage?
    /// Index into `preview.candidates`: the English word for Russian input.
    private(set) var candidateIndex = 0
    private var fallback = MachineFallback()

    @ObservationIgnored private let lookup: (String) throws -> QuickAddPreview?
    @ObservationIgnored private let translator: MachineTranslator?
    @ObservationIgnored private let chain: EnglishDetailsChain
    @ObservationIgnored let showsExampleTranslation: Bool
    @ObservationIgnored private var pendingLookup: Task<Void, Never>?
    @ObservationIgnored private var pendingTranslation: Task<Void, Never>?

    init(
        text: String = "",
        example: String = "",
        translator: MachineTranslator? = nil,
        showsExampleTranslation: Bool = false,
        details: @escaping (String) throws -> QuickAddCandidate? = { _ in nil },
        lookup: @escaping (String) throws -> QuickAddPreview?
    ) {
        chain = EnglishDetailsChain(delay: Self.lookupDelay, lookup: details)
        self.text = text
        self.example = example
        self.translator = translator
        self.showsExampleTranslation = showsExampleTranslation
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
        preview?.russianText == nil ? [] : preview?.candidates ?? []
    }

    /// What the panel shows for the word on the card. For Russian input it is the details asked again
    /// for the English word; until they arrive, the candidate's own.
    var details: QuickAddCandidate? {
        guard isRussianInput else { return candidate }
        if let chained = chain.details(for: chainedWord) { return chained }
        return needsEnglishWord ? nil : candidate
    }

    /// The English word of a Russian input whose details are asked again. A bundled candidate has
    /// them already.
    private var chainedWord: String? {
        guard isRussianInput else { return nil }
        if needsEnglishWord {
            let word = chosenEnglishWord
            return word.isEmpty || englishWordProblem != nil ? nil : word
        }
        guard let candidate, candidate.lookup == nil else { return nil }
        return candidate.headword
    }

    /// The typed Russian word is the translation, so there is none to choose.
    var isRussianInput: Bool { preview?.isRussianInput == true }

    /// Russian text with no candidates: the learner (or the translator) gives the English word.
    var needsEnglishWord: Bool { isRussianInput && candidates.isEmpty }

    var translations: [String] {
        guard !isRussianInput else { return [] }
        return candidate?.translations ?? []
    }

    /// Words the dictionary lacks always need the custom field.
    var showsCustomField: Bool {
        guard !isRussianInput else { return false }
        return preview != nil && choice == .custom
    }

    /// Russian text with no candidates: the field shows until the learner picks the machine bubble.
    var showsEnglishWordField: Bool { needsEnglishWord && choice == .custom }

    var machine: MachineSuggestion { fallback.suggestion }

    /// The machine result as a bubble; `nil` until it arrives.
    var machineBubble: String? { fallback.bubble }

    var chosenTranslation: String {
        if let preview, preview.isRussianInput { return preview.russianText ?? preview.headword }
        return switch choice {
        case .dictionary(let index) where translations.indices.contains(index): translations[index]
        case .machine: machineBubble ?? customTranslation
        case .dictionary, .custom: customTranslation
        }
    }

    /// The English word for Russian text the dictionary does not know.
    private var chosenEnglishWord: String {
        choice == .machine ? machineBubble ?? "" : Self.trimmed(englishWord)
    }

    /// Cyrillic in the English word field, shown at once and not only after Add.
    var englishWordProblem: LingvoCoreError? {
        needsEnglishWord ? EnglishWordInput.problem(in: chosenEnglishWord) : nil
    }

    var canSubmit: Bool {
        if needsEnglishWord { return !chosenEnglishWord.isEmpty && englishWordProblem == nil }
        guard let candidate, candidate.canAdd else { return false }
        return !Self.trimmed(chosenTranslation).isEmpty
    }

    func choose(_ choice: TranslationChoice) {
        self.choice = choice
        if message.isError { message = nil }
        syncDetails(delayed: false)
    }

    func chooseCandidate(_ index: Int) {
        guard candidates.indices.contains(index) else { return }
        candidateIndex = index
        message = Self.standingMessage(for: candidate)
        syncDetails(delayed: false)
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
        if needsEnglishWord { return englishWordSubmission() }
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

    /// The panel stays open while the system download sheet is up.
    var isDownloadingLanguagePack: Bool { machine == .downloading }

    /// Only this starts the system download sheet; the translation is asked again after it.
    func downloadLanguagePack() {
        guard let translator, let next = fallback.downloading(), let request = next.request else { return }
        fallback = next
        pendingTranslation = Task { [weak self] in
            await translator.downloadLanguagePack(for: request.direction)
            guard !Task.isCancelled, let self, let again = self.fallback.askingAgain(request) else { return }
            self.fallback = again
            self.ask(translator, request)
        }
    }

    /// Snapshots render the state after the fake translator has answered and the details came.
    func machineTranslationSettled() async {
        await pendingTranslation?.value
        await chain.settled()
    }

    private func englishWordSubmission() -> NewMyWord? {
        if let problem = englishWordProblem {
            message = .error(problem.localizedDescription)
            return nil
        }
        guard canSubmit else {
            message = .error(String(localized: "Type the English word for the card."))
            return nil
        }
        return NewMyWord(text: chosenEnglishWord, translation: chosenTranslation, example: example)
    }

    private func scheduleLookup() {
        pendingLookup?.cancel()
        pendingLookup = Task { [weak self] in
            try? await Task.sleep(for: Self.lookupDelay)
            guard !Task.isCancelled else { return }
            self?.refreshPreview()
        }
    }

    /// The first dictionary translation and the first candidate are preselected
    /// for each new word; a choice made for the same word survives further edits
    /// (a trailing space).
    private func refreshPreview() {
        pendingLookup?.cancel()
        pendingLookup = nil
        let previous = preview
        var failure: QuickAddMessage?
        do {
            preview = try lookup(text)
        } catch {
            preview = nil
            failure = .error(error.localizedDescription)
        }
        if !QuickAddPreview.keepsChoices(from: previous, to: preview) {
            candidateIndex = 0
            choice = .preselected(translations: translations)
        }
        // Unknown Russian text is not the word that gets added, so its own standing does not matter.
        message = failure ?? (needsEnglishWord ? nil : Self.standingMessage(for: candidate))
        requestMachineTranslation()
        syncDetails(delayed: false)
    }

    private func syncDetails(delayed: Bool) {
        chain.want(chainedWord, delayed: delayed)
    }

    private func requestMachineTranslation() {
        let request = MachineTranslationRequest(preview: preview, candidate: candidate)
        guard let next = fallback.requesting(request, canAsk: translator != nil) else { return }
        pendingTranslation?.cancel()
        pendingTranslation = nil
        choice = choice.droppingMachine
        fallback = next
        if next.suggestion == .waiting, let translator, let request = next.request {
            ask(translator, request)
        }
    }

    private func ask(_ translator: MachineTranslator, _ request: MachineTranslationRequest) {
        pendingTranslation = Task { [weak self] in
            let result = await translator.translate(request)
            guard !Task.isCancelled else { return }
            self?.receive(result, for: request)
        }
    }

    private func receive(_ result: MachineTranslation, for request: MachineTranslationRequest) {
        guard let next = fallback.receiving(result, for: request) else { return }
        pendingTranslation = nil
        fallback = next
        guard next.bubble != nil else { return }
        choice = choice.afterSuggestion(typed: request.direction == .englishToRussian ? customTranslation : englishWord)
        syncDetails(delayed: true)
    }

    /// A newer keystroke cancels the request at once; the lookup after the pause asks again.
    private func cancelWaitingTranslation() {
        guard let next = fallback.cancellingWait() else { return }
        pendingTranslation?.cancel()
        pendingTranslation = nil
        fallback = next
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func standingMessage(for candidate: QuickAddCandidate?) -> QuickAddMessage? {
        candidate.flatMap { $0.canAdd ? nil : .standing($0.standing) }
    }
}

private extension Optional where Wrapped == QuickAddMessage {
    var isError: Bool {
        if case .error = self { true } else { false }
    }
}
