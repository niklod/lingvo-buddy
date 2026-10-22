import AppKit

enum QuickAddKeyCommand: Equatable {
    case submit
    case cancel

    init?(event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        guard modifiers.isEmpty else { return nil }
        switch event.keyCode {
        case KeyCode.escape: self = .cancel
        case _ where KeyCode.returnKeys.contains(event.keyCode): self = .submit
        default: return nil
        }
    }
}

/// The quick-add panel takes key status without activating the app, so typing
/// goes to quick add while the app the learner works in stays frontmost.
@MainActor
final class QuickAddPanel: FloatingPanel {
    var onKey: (QuickAddKeyCommand) -> Void = { _ in }
    var onResignKey: () -> Void = {}

    init() {
        // The custom translation field appears after open; the panel keeps its top edge.
        super.init(keepsTopEdge: true)
    }

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

    private var isComposingText: Bool {
        (firstResponder as? NSTextView)?.hasMarkedText() == true
    }
}
