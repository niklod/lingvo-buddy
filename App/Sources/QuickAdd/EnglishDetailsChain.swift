import LingvoCore
import Observation
import OSLog

/// Runs the loads that `ChainedDetails` asks for: the details of the English word a Russian input
/// gets for its card.
@MainActor
@Observable
final class EnglishDetailsChain {
    private var state = ChainedDetails()

    @ObservationIgnored private let lookup: (String) throws -> QuickAddCandidate?
    @ObservationIgnored private let delay: Duration
    @ObservationIgnored private let logger = Logger.app(category: "quick-add")
    @ObservationIgnored private var pending: Task<Void, Never>?

    init(delay: Duration, lookup: @escaping (String) throws -> QuickAddCandidate?) {
        self.delay = delay
        self.lookup = lookup
    }

    /// `nil` until the lookup for exactly this word is done.
    func details(for word: String?) -> QuickAddCandidate? {
        state.details(for: word)
    }

    func want(_ word: String?, delayed: Bool) {
        let (next, step) = state.wanting(word, delayed: delayed)
        state = next
        switch step {
        case .keep:
            return
        case .cancel:
            cancelPending()
        case .load(let word):
            cancelPending()
            load(word)
        case .loadAfterPause(let word):
            cancelPending()
            pending = Task { [weak self, delay] in
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled else { return }
                self?.load(word)
            }
        }
    }

    /// Snapshots render the state after the pause.
    func settled() async {
        await pending?.value
    }

    private func cancelPending() {
        pending?.cancel()
        pending = nil
    }

    private func load(_ word: String) {
        pending = nil
        let result = Result { try lookup(word) }
        if case .failure(let error) = result {
            logger.error("details lookup failed: \(String(describing: error), privacy: .private)")
        }
        state = state.receiving(result, for: word)
    }
}
