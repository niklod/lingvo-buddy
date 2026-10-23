import LingvoCore
import Observation

/// The one place the app holds the current update state. The tray header reads it; the menu-bar
/// icon (#57) observes `state`; the Sparkle user driver (#59) feeds it with `send` and installs
/// on `onInstallRequested`.
@MainActor
@Observable
final class UpdateCenter {
    private(set) var state: UpdateState

    /// Called after a click moved the state to `downloading`: start or restart the real download.
    @ObservationIgnored var onInstallRequested: () -> Void = {}

    init(state: UpdateState = .idle) {
        self.state = state
    }

    func send(_ event: UpdateEvent) {
        state = state.applying(event)
    }

    /// The learner clicked the update button. A click the state does not accept does nothing.
    func clickInstall() {
        let before = state
        send(.installClicked)
        if state != before { onInstallRequested() }
    }

    /// QA only (`--update-state`): jumps to a state that no event sequence reaches without Sparkle.
    func force(_ state: UpdateState) {
        self.state = state
    }
}
