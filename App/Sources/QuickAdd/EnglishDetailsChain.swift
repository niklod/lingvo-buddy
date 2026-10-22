import LingvoCore
import Observation
import OSLog

/// The details of the English word a Russian input gets for its card. The word changes with a picked
/// bubble, a typed word or a machine translation; the details follow it, and details of an older
/// word are never handed out.
@MainActor
@Observable
final class EnglishDetailsChain {
    private struct Result {
        let word: String
        let candidate: QuickAddCandidate
    }

    private var result: Result?

    @ObservationIgnored private let lookup: (String) throws -> QuickAddCandidate?
    @ObservationIgnored private let delay: Duration
    @ObservationIgnored private let logger = Logger.app(category: "quick-add")
    @ObservationIgnored private var pending: Task<Void, Never>?
    @ObservationIgnored private var wanted: String?

    init(delay: Duration, lookup: @escaping (String) throws -> QuickAddCandidate?) {
        self.delay = delay
        self.lookup = lookup
    }

    /// `nil` until the lookup for exactly this word is done.
    func details(for word: String?) -> QuickAddCandidate? {
        guard let word, result?.word == word else { return nil }
        return result?.candidate
    }

    /// A newer word cancels the older request at once. A typed or machine word waits for the typing
    /// pause, so a burst of keystrokes asks once; a click or a new preview asks now.
    func want(_ word: String?, delayed: Bool) {
        let upgradesPending = !delayed && pending != nil
        guard word != wanted || upgradesPending else { return }
        pending?.cancel()
        pending = nil
        wanted = word
        guard let word, result?.word != word else { return }
        if delayed {
            pending = Task { [weak self, delay] in
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled else { return }
                self?.load(word)
            }
        } else {
            load(word)
        }
    }

    /// Snapshots render the state after the pause.
    func settled() async {
        await pending?.value
    }

    private func load(_ word: String) {
        pending = nil
        do {
            result = try lookup(word).map { Result(word: word, candidate: $0) }
        } catch {
            // The details only enrich the panel; Add looks the word up again, so a failure shows none.
            logger.error("details lookup failed: \(String(describing: error), privacy: .private)")
            result = nil
        }
    }
}
