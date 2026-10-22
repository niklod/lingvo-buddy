import AppKit

/// The card panel never activates the app, so the frontmost app keeps keyboard
/// focus when a card appears. A click or ⌥⌘W makes it key (still without
/// activating the app); then the keys reach `onKey`.
@MainActor
final class CardPanel: FloatingPanel {
    /// Returns `true` when the key press was handled.
    var onKey: (CardKeyCommand) -> Bool = { _ in false }
    var onBecameKey: () -> Void = {}

    init() {
        // The feedback block appears after an answer; the card stays under the menu bar.
        super.init(keepsTopEdge: true)
    }

    override func becomeKey() {
        super.becomeKey()
        onBecameKey()
    }

    /// Keys are caught before SwiftUI sees them, so Enter always means "Next" and
    /// never clicks a focused option. Space is left to the focused button: that is
    /// how Full Keyboard Access presses it.
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown, !isKeyWindow {
            makeKey()
        }
        if event.type == .keyDown, let command = CardKeyCommand(event: event), onKey(command) {
            return
        }
        super.sendEvent(event)
    }
}
