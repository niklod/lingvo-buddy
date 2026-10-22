import Foundation

/// The details of the English word a Russian input gets for its card. The word changes with a picked
/// bubble, a typed word or a machine translation; the details follow it, and details of an older
/// word are never handed out. The caller runs the loads; this value decides when and keeps the result.
public struct ChainedDetails: Sendable {
    /// What the caller does with its pending load after `wanting`.
    public enum Step: Equatable, Sendable {
        /// Nothing changes; a pending load goes on.
        case keep
        /// Cancel the pending load; there is nothing to load.
        case cancel
        /// Cancel the pending load and load this word now.
        case load(String)
        /// Cancel the pending load and load this word after the typing pause.
        case loadAfterPause(String)
    }

    private struct Loaded: Sendable {
        let word: String
        let candidate: QuickAddCandidate
    }

    private var wanted: String?
    private var waitsForPause = false
    private var loaded: Loaded?

    public init() {}

    /// `nil` until the load for exactly this word is done.
    public func details(for word: String?) -> QuickAddCandidate? {
        guard let word, loaded?.word == word else { return nil }
        return loaded?.candidate
    }

    /// A newer word cancels the older load at once. A typed or machine word waits for the typing
    /// pause, so a burst of keystrokes loads once; a click or a new preview loads now.
    public func wanting(_ word: String?, delayed: Bool) -> (details: ChainedDetails, step: Step) {
        let upgradesPending = !delayed && waitsForPause
        guard word != wanted || upgradesPending else { return (self, .keep) }
        var next = self
        next.wanted = word
        next.waitsForPause = false
        guard let word, loaded?.word != word else { return (next, .cancel) }
        guard delayed else { return (next, .load(word)) }
        next.waitsForPause = true
        return (next, .loadAfterPause(word))
    }

    /// The result of a load. A word no longer wanted is dropped, and a failed load shows no details:
    /// they only enrich the panel, and Add looks the word up again.
    public func receiving(_ result: Result<QuickAddCandidate?, any Error>, for word: String) -> ChainedDetails {
        guard word == wanted else { return self }
        var next = self
        next.waitsForPause = false
        next.loaded = (try? result.get()).map { Loaded(word: word, candidate: $0) }
        return next
    }
}
