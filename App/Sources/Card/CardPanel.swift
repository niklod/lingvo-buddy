import AppKit
import SwiftUI

/// A borderless panel that never activates the app, so the frontmost app keeps
/// keyboard focus when a card appears.
@MainActor
final class CardPanel: NSPanel {
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
        becomesKeyOnlyIfNeeded = true
        isOpaque = false
        backgroundColor = .clear
        // The SwiftUI view draws the design shadow itself.
        hasShadow = false
        isMovable = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

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
