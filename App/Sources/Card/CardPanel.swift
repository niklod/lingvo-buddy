import AppKit

/// The card panel never activates the app, so the frontmost app keeps keyboard
/// focus when a card appears. A click or ⌥⌘W makes it key (still without
/// activating the app); then the keys reach `onKey`.
@MainActor
final class CardPanel: FloatingPanel {
    /// Returns `true` when the key press was handled.
    var onKey: (CardKeyCommand) -> Bool = { _ in false }
    var onBecameKey: () -> Void = {}

    /// When another of our panels (tray, quick add) closes, AppKit hands key status
    /// to the next window that accepts it. An untouched timed card must not take it:
    /// it would catch the learner's typing and never auto-close.
    private var acceptsKeyFocus = false

    init() {
        // The feedback block appears after an answer; the card stays under the menu bar.
        super.init(keepsTopEdge: true)
    }

    override var canBecomeKey: Bool { acceptsKeyFocus }

    /// The learner asked for the card (click, ⌥⌘W, menu): from now on it may be key.
    func takeKeyFocus() {
        acceptsKeyFocus = true
        makeKeyAndOrderFront(nil)
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
            takeKeyFocus()
        }
        if event.type == .keyDown, let command = CardKeyCommand(event: event), onKey(command) {
            return
        }
        super.sendEvent(event)
    }
}
