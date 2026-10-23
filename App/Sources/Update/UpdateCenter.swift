import LingvoCore
import Observation

/// The one place the app holds the current update state. The tray header and the menu-bar icon
/// observe `state`; the Sparkle user driver feeds it with `send` and installs on
/// `onInstallRequested`.
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
        let next = state.applying(event)
        // Sparkle reports every chunk; an equal write would still redraw every observer.
        if next != state { state = next }
    }

    /// The learner clicked the update button. A click the state does not accept does nothing.
    func clickInstall() {
        let before = state
        send(.installClicked)
        if state != before { onInstallRequested() }
    }

    #if DEBUG
    /// QA only (`--update-state`): jumps to a state that no event sequence reaches without Sparkle.
    func force(_ state: UpdateState) {
        self.state = state
    }
    #endif
}
