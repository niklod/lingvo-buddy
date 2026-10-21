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

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func becomeKey() {
        super.becomeKey()
        onBecameKey()
    }

    /// Keys are caught before SwiftUI sees them, so a focused button cannot
    /// turn Enter or Space into a click.
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown, !isKeyWindow {
            makeKey()
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
