import AppKit
import Observation

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
    private static let glyphs = StatusGlyphImages()

    private let statusItem: NSStatusItem
    private let actions: StatusItemActions
    private let update: UpdateCenter
    private var marks = StatusMarks()

    init(update: UpdateCenter, actions: StatusItemActions) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.actions = actions
        self.update = update
        super.init()
        guard let button = statusItem.button else { return }
        button.image = Self.glyphs.image(marks)
        button.setAccessibilityTitle("LingvoBuddy")
        button.target = self
        button.action = #selector(clicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        observeUpdateMark()
    }

    var anchor: NSStatusBarButton? { statusItem.button }

    func showWaitingDot(_ waiting: Bool) {
        show(StatusMarks(waiting: waiting, updateMark: marks.updateMark))
    }

    /// Re-arms the observation after every change: `withObservationTracking` fires once per registration.
    private func observeUpdateMark() {
        let shows = withObservationTracking {
            update.state.showsUpdateMark
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in self?.observeUpdateMark() }
        }
        show(StatusMarks(waiting: marks.waiting, updateMark: shows))
    }

    /// A new image makes the menu bar lay out and redraw the item, so only a change sets one.
    private func show(_ next: StatusMarks) {
        guard next != marks else { return }
        marks = next
        statusItem.button?.image = Self.glyphs.image(next)
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
