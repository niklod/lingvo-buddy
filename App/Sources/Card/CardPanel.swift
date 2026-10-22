import AppKit
import SwiftUI

/// A borderless panel that never activates the app, so the frontmost app keeps
/// keyboard focus when a card appears. A click or ⌥⌘W makes it key (still
/// without activating the app); then the keys reach `onKey`.
@MainActor
final class CardPanel: NSPanel {
    /// Returns `true` when the key press was handled.
    var onKey: (CardKeyCommand) -> Bool = { _ in false }
    var onBecameKey: () -> Void = {}

    init() {
        // .nonactivatingPanel must be set at init: toggling it later does not
        // update the window server.
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        hidesOnDeactivate = false
        // A click anywhere on the card must give it keyboard focus, not only a click on a text field.
        becomesKeyOnlyIfNeeded = false
        animationBehavior = .none
        isOpaque = false
        backgroundColor = .clear
        // The SwiftUI view draws the design shadow itself.
        hasShadow = false
        isMovable = false
    }

    /// When another of our panels (tray, quick add) closes, AppKit hands key status
    /// to the next window that accepts it. An untouched timed card must not take it:
    /// it would catch the learner's typing and never auto-close.
    private var acceptsKeyFocus = false

    override var canBecomeKey: Bool { acceptsKeyFocus }
    override var canBecomeMain: Bool { false }

    /// The learner asked for the card (click, ⌥⌘W, menu): from now on it may be key.
    func takeKeyFocus() {
        acceptsKeyFocus = true
        makeKeyAndOrderFront(nil)
    }

    override func becomeKey() {
        super.becomeKey()
        onBecameKey()
    }

    /// Keys are caught before SwiftUI sees them, so a focused button cannot
    /// turn Enter or Space into a click.
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown, !isKeyWindow {
            takeKeyFocus()
        }
        if event.type == .keyDown, let command = CardKeyCommand(event: event), onKey(command) {
            return
        }
        super.sendEvent(event)
    }

    /// AppKit keeps the bottom-left corner when the content grows (the feedback
    /// block appears after an answer); the card must instead stay pinned under the menu bar.
    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        guard isVisible, frameRect.height != frame.height else {
            super.setFrame(frameRect, display: flag)
            return
        }
        var pinned = frameRect
        pinned.origin.y = frame.maxY - frameRect.height
        super.setFrame(pinned, display: flag)
    }

    func setContent(_ view: some View) {
        let controller = NSHostingController(rootView: view)
        controller.sizingOptions = [.preferredContentSize]
        contentViewController = controller
        let unbounded = CGFloat.greatestFiniteMagnitude
        setContentSize(controller.sizeThatFits(in: NSSize(width: unbounded, height: unbounded)))
    }
}
