import AppKit

struct StatusItemActions {
    /// A left click; returns `true` when it reopened a waiting card, so the tray stays closed.
    var primaryClick: () -> Bool = { false }
    /// Opens or closes the tray menu under the icon.
    var toggleTray: (NSStatusBarButton) -> Void = { _ in }
}

/// The Kapa status item. A left click reopens a waiting card (dot shown);
/// otherwise, and on a right click, it toggles the tray menu.
@MainActor
final class StatusItemController: NSObject {
    /// Built once: `arm()` asks for the dot on every timer event, all day long.
    private static let plainGlyph = StatusGlyph.image(waiting: false)
    private static let waitingGlyph = StatusGlyph.image(waiting: true)

    private let statusItem: NSStatusItem
    private let actions: StatusItemActions
    private var showsWaitingDot = false

    init(actions: StatusItemActions) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.actions = actions
        super.init()
        guard let button = statusItem.button else { return }
        button.image = Self.plainGlyph
        button.setAccessibilityTitle("LingvoBuddy")
        button.target = self
        button.action = #selector(clicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    var anchor: NSStatusBarButton? { statusItem.button }

    /// A new image makes the menu bar lay out and redraw the item, so only a change sets one.
    func showWaitingDot(_ waiting: Bool) {
        guard waiting != showsWaitingDot else { return }
        showsWaitingDot = waiting
        statusItem.button?.image = waiting ? Self.waitingGlyph : Self.plainGlyph
    }

    @objc private func clicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let secondary = event?.type == .rightMouseUp
            || event?.modifierFlags.contains(.control) == true
            || event?.modifierFlags.contains(.option) == true
        if !secondary, actions.primaryClick() {
            return
        }
        actions.toggleTray(sender)
    }
}
