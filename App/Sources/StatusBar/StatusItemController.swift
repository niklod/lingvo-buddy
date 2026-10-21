import AppKit
import LingvoCore

struct StatusItemActions {
    /// A left click; returns `true` when it reopened a waiting card, so no menu opens.
    var primaryClick: () -> Bool = { false }
    var showWordNow: () -> Void = {}
    var pause: (PauseOption) -> Void = { _ in }
    var resume: () -> Void = {}
    var pausedUntil: () -> Date? = { nil }
}

/// The "Aa" status item. A left click reopens a waiting card (dot shown);
/// otherwise it opens a small menu until the tray menu slice replaces it.
@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let actions: StatusItemActions

    init(actions: StatusItemActions) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.actions = actions
        super.init()
        guard let button = statusItem.button else { return }
        button.image = StatusGlyph.image()
        button.setAccessibilityTitle("LingvoBuddy")
        button.target = self
        button.action = #selector(clicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    var anchor: NSStatusBarButton? { statusItem.button }

    func showWaitingDot(_ waiting: Bool) {
        statusItem.button?.image = StatusGlyph.image(waiting: waiting)
    }

    @objc private func clicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let secondary = event?.type == .rightMouseUp
            || event?.modifierFlags.contains(.control) == true
            || event?.modifierFlags.contains(.option) == true
        if !secondary, actions.primaryClick() {
            return
        }
        openMenu()
    }

    /// A permanent `statusItem.menu` would take every left click, including the
    /// one that must reopen a waiting card, so the menu is attached only for this click.
    private func openMenu() {
        statusItem.menu = StatusMenu.make(target: self, pausedUntil: actions.pausedUntil())
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc func showWordNowClicked() {
        actions.showWordNow()
    }

    @objc func pauseClicked(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let option = PauseOption(rawValue: raw) else { return }
        actions.pause(option)
    }

    @objc func resumeClicked() {
        actions.resume()
    }
}

@MainActor
private enum StatusMenu {
    static func make(target: StatusItemController, pausedUntil: Date?) -> NSMenu {
        let menu = NSMenu()
        let show = NSMenuItem(
            title: String(localized: "Show word now"),
            action: #selector(StatusItemController.showWordNowClicked),
            keyEquivalent: "w"
        )
        show.keyEquivalentModifierMask = [.option, .command]
        show.target = target
        menu.addItem(show)
        menu.addItem(.separator())
        if let pausedUntil {
            let time = pausedUntil.formatted(date: .omitted, time: .shortened)
            let status = NSMenuItem(title: String(localized: "Paused until \(time)"), action: nil, keyEquivalent: "")
            status.isEnabled = false
            menu.addItem(status)
        }
        let pause = NSMenuItem(title: String(localized: "Pause"), action: nil, keyEquivalent: "")
        pause.submenu = pauseMenu(target: target, isPaused: pausedUntil != nil)
        menu.addItem(pause)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: String(localized: "Quit"),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        return menu
    }

    private static func pauseMenu(target: StatusItemController, isPaused: Bool) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        for option in PauseOption.allCases {
            let item = NSMenuItem(
                title: title(for: option),
                action: #selector(StatusItemController.pauseClicked(_:)),
                keyEquivalent: ""
            )
            item.representedObject = option.rawValue
            item.target = target
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let resume = NSMenuItem(
            title: String(localized: "Resume"),
            action: #selector(StatusItemController.resumeClicked),
            keyEquivalent: ""
        )
        resume.target = target
        resume.isEnabled = isPaused
        menu.addItem(resume)
        return menu
    }

    private static func title(for option: PauseOption) -> String {
        switch option {
        case .oneHour: String(localized: "For 1 hour")
        case .threeHours: String(localized: "For 3 hours")
        case .untilTomorrow: String(localized: "Until tomorrow")
        }
    }
}
