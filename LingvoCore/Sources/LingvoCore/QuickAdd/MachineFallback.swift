import Foundation

/// The two ways quick add asks the system translator.
public enum MachineTranslationDirection: Equatable, Sendable {
    /// An English word outside the dictionary: the suggestion is the card's translation.
    case englishToRussian
    /// Russian text with no English candidates: the suggestion is the card's English word.
    case russianToEnglish
}

public struct MachineTranslationRequest: Equatable, Sendable {
    public let text: String
    public let direction: MachineTranslationDirection

    public init(text: String, direction: MachineTranslationDirection) {
        self.text = text
        self.direction = direction
    }

    /// What to ask when no dictionary has a match: an English word outside all of them, or Russian
    /// text with no candidates. `nil` when there is nothing to ask.
    public init?(preview: QuickAddPreview?, candidate: QuickAddCandidate?) {
        guard let preview, let candidate, preview.russianText == nil, candidate.lookup == nil else { return nil }
        if preview.isRussianInput {
            self.init(text: preview.headword, direction: .russianToEnglish)
            return
        }
        // Reviewed or Wiktionary translations win: the machine is asked only when no dictionary has one.
        guard candidate.canAdd, candidate.translations.isEmpty else { return nil }
        self.init(text: preview.headword, direction: .englishToRussian)
    }
}

public enum MachineTranslation: Equatable, Sendable {
    case translated(String)
    /// The system has the language pair but not its offline pack. Only the
    /// learner's click may start the download, so the translator never does it on its own.
    case languagePackMissing
    /// The details go to the log; the panel shows one short line.
    case failed
}

/// Where the machine translation fallback stands for the typed word.
public enum MachineSuggestion: Equatable, Sendable {
    /// The dictionary has a match, or there is nothing to ask.
    case none
    case waiting
    case suggested(String)
    case languagePackMissing
    case downloading
    case failed
}

/// The machine translation request of the quick-add panel and its answer. Only the answer to the
/// current request may show: a newer word makes any older answer stale.
public struct MachineFallback: Equatable, Sendable {
    public private(set) var request: MachineTranslationRequest?
    public private(set) var suggestion: MachineSuggestion = .none

    public init() {}

    /// `nil` when the request is the current one: the same word keeps its answer (a trailing
    /// space does not ask again). Otherwise the caller drops the older request and asks when
    /// the suggestion is `.waiting`.
    public func requesting(_ request: MachineTranslationRequest?, canAsk: Bool) -> MachineFallback? {
        guard request != self.request else { return nil }
        var next = MachineFallback()
        next.request = request
        next.suggestion = request != nil && canAsk ? .waiting : .none
        return next
    }

    /// `nil` for an answer to a request that is no longer current.
    public func receiving(_ result: MachineTranslation, for request: MachineTranslationRequest) -> MachineFallback? {
        guard request == self.request else { return nil }
        var next = self
        next.suggestion = switch result {
        case .translated(let text): .suggested(text)
        case .languagePackMissing: .languagePackMissing
        case .failed: .failed
        }
        return next
    }

    /// A newer keystroke drops a request still waiting; the lookup after the pause asks again.
    /// `nil` when nothing waits.
    public func cancellingWait() -> MachineFallback? {
        guard suggestion == .waiting else { return nil }
        return MachineFallback()
    }

    /// Only a missing language pack can start the download. `nil` otherwise.
    public func downloading() -> MachineFallback? {
        guard suggestion == .languagePackMissing, request != nil else { return nil }
        var next = self
        next.suggestion = .downloading
        return next
    }

    /// After the download the same request is asked again. `nil` when the request changed meanwhile.
    public func askingAgain(_ request: MachineTranslationRequest) -> MachineFallback? {
        guard request == self.request else { return nil }
        var next = self
        next.suggestion = .waiting
        return next
    }

    /// The suggestion as a bubble; `nil` until it arrives.
    public var bubble: String? {
        guard case .suggested(let text) = suggestion else { return nil }
        return text
    }
}
