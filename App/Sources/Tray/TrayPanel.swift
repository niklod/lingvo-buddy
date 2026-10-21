import AppKit
import SwiftUI

/// The keys the open tray menu answers to, like the shortcuts a native menu shows.
enum TrayKeyCommand: Equatable {
    case close
    case openDictionary
    case openSettings
    case quit

    private static let escape: UInt16 = 53

    init?(event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        if modifiers.isEmpty, event.keyCode == Self.escape {
            self = .close
            return
        }
        guard modifiers == .command else { return nil }
        switch event.charactersIgnoringModifiers {
        case "d": self = .openDictionary
        case ",": self = .openSettings
        case "q": self = .quit
        case "w": self = .close
        default: return nil
        }
    }
}

/// A borderless panel that takes key status without activating the app, so
/// the tray keys work while the frontmost app stays frontmost.
@MainActor
final class TrayPanel: NSPanel {
    /// Returns `true` when the key press was handled.
    var onKey: (TrayKeyCommand) -> Bool = { _ in false }

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

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, let command = TrayKeyCommand(event: event), onKey(command) {
            return
        }
        super.sendEvent(event)
    }

    func setContent(_ view: some View) {
        let controller = NSHostingController(rootView: view)
        controller.sizingOptions = [.preferredContentSize]
        contentViewController = controller
        let unbounded = CGFloat.greatestFiniteMagnitude
        setContentSize(controller.sizeThatFits(in: NSSize(width: unbounded, height: unbounded)))
    }
}
