import AppKit
import LingvoCore

/// The native submenus behind the "›" rows of the tray menu.
@MainActor
enum TraySubmenus {
    /// Interval choices inside the Settings range (5–120 min).
    static let intervalMinutes = [5, 10, 15, 20, 30, 45, 60, 90, 120]

    static func intervals(current: TimeInterval, choose: @escaping (TimeInterval) -> Void) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        for minutes in intervalMinutes {
            let interval = TimeInterval(minutes * 60)
            let item = ClosureMenuItem(title: String(localized: "Every \(minutes) min")) { choose(interval) }
            item.state = interval == current ? .on : .off
            menu.addItem(item)
        }
        return menu
    }

    static func pause(choose: @escaping (PauseOption) -> Void) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        for option in PauseOption.allCases {
            menu.addItem(ClosureMenuItem(title: title(for: option)) { choose(option) })
        }
        return menu
    }

    private static func title(for option: PauseOption) -> String {
        switch option {
        case .oneHour: String(localized: "For 1 hour")
        case .threeHours: String(localized: "For 3 hours")
        case .untilTomorrow: String(localized: "Until tomorrow")
        }
    }

    /// Opens the menu beside the tray like a native submenu: to the right when
    /// it fits, else to the left (the tray usually sits at the right screen edge).
    /// The mouse is on the row that was just clicked, so its height sets the top.
    static func popUp(_ menu: NSMenu, beside trayFrame: NSRect?) {
        let mouse = NSEvent.mouseLocation
        guard let trayFrame else {
            menu.popUp(positioning: nil, at: mouse, in: nil)
            return
        }
        let insets = Theme.CardShadow.insets
        let visibleLeft = trayFrame.minX + insets.leading
        let visibleRight = trayFrame.maxX - insets.trailing
        let screenRight = NSScreen.screens.first { $0.frame.contains(mouse) }?.visibleFrame.maxX ?? .greatestFiniteMagnitude
        let width = menu.size.width
        let x = visibleRight + width <= screenRight ? visibleRight : visibleLeft - width
        menu.popUp(positioning: nil, at: NSPoint(x: x, y: mouse.y + rowHalfHeight), in: nil)
    }

    private static let rowHalfHeight: CGFloat = 17
}

/// A menu item that runs a closure, so submenus need no @objc target class.
final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("ClosureMenuItem is not created from a nib")
    }

    @objc private func fire() {
        handler()
    }
}
