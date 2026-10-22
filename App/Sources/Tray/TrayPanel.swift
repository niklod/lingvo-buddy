import AppKit

/// The keys the open tray menu answers to, like the shortcuts a native menu shows.
enum TrayKeyCommand: Equatable {
    case close
    case openDictionary
    case openSettings
    case quit

    init?(event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        if modifiers.isEmpty, event.keyCode == KeyCode.escape {
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

/// The tray panel takes key status without activating the app, so the tray
/// keys work while the frontmost app stays frontmost.
@MainActor
final class TrayPanel: FloatingPanel {
    /// Returns `true` when the key press was handled.
    var onKey: (TrayKeyCommand) -> Bool = { _ in false }

    init() {
        super.init(keepsTopEdge: false)
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, let command = TrayKeyCommand(event: event), onKey(command) {
            return
        }
        super.sendEvent(event)
    }
}
