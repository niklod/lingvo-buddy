import AppKit
import SwiftUI

/// A borderless panel that takes key status without activating the app, so the
/// frontmost app keeps its place while the card, the tray or quick add has the keys.
@MainActor
class FloatingPanel: NSPanel {
    /// AppKit keeps the bottom-left corner when the content grows. Panels that
    /// grow after they open (card feedback, quick add's custom field) must keep
    /// their top edge instead, under the menu bar.
    private let keepsTopEdge: Bool

    init(keepsTopEdge: Bool) {
        self.keepsTopEdge = keepsTopEdge
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
        // A click anywhere on the panel must give it keyboard focus, not only a click on a text field.
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

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        guard keepsTopEdge, isVisible, frameRect.height != frame.height else {
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
