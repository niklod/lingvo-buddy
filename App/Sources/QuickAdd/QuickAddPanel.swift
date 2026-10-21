import AppKit
import SwiftUI

enum QuickAddKeyCommand: Equatable {
    case submit
    case cancel

    private static let escape: UInt16 = 53
    private static let returnKey: UInt16 = 36
    private static let keypadEnter: UInt16 = 76

    init?(event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        guard modifiers.isEmpty else { return nil }
        switch event.keyCode {
        case Self.escape: self = .cancel
        case Self.returnKey, Self.keypadEnter: self = .submit
        default: return nil
        }
    }
}

/// A borderless panel that takes key status without activating the app, so
/// typing goes to quick add while the app the learner works in stays frontmost.
@MainActor
final class QuickAddPanel: NSPanel {
    var onKey: (QuickAddKeyCommand) -> Void = { _ in }
    var onResignKey: () -> Void = {}

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

    override func resignKey() {
        super.resignKey()
        onResignKey()
    }

    /// Enter and Esc work from every field and from a clicked pill. While an
    /// input method composes text, the keys belong to it.
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, !isComposingText, let command = QuickAddKeyCommand(event: event) {
            onKey(command)
            return
        }
        super.sendEvent(event)
    }

    /// AppKit keeps the bottom-left corner when the content grows (the custom
    /// translation field appears); the panel must keep its top edge instead.
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

    private var isComposingText: Bool {
        (firstResponder as? NSTextView)?.hasMarkedText() == true
    }
}
