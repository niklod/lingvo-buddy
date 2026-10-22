import AppKit

/// The keys a focused card answers to: 1–4 pick an option, Enter goes next, Esc closes.
enum CardKeyCommand: Equatable {
    case pick(Int)
    case next
    case close

    init?(event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.command, .control, .option])
        guard modifiers.isEmpty else { return nil }
        switch event.keyCode {
        case KeyCode.escape: self = .close
        case _ where KeyCode.returnKeys.contains(event.keyCode): self = .next
        default:
            guard let digit = event.charactersIgnoringModifiers.flatMap(Int.init), (1...4).contains(digit) else {
                return nil
            }
            self = .pick(digit - 1)
        }
    }
}
