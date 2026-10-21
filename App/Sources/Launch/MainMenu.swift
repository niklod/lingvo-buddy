import AppKit

/// A menu-bar app shows no main menu, but AppKit still matches key
/// equivalents against it while one of our windows is key: this is what makes
/// ⌘, ⌘W ⌘Q and copy/paste work in the Settings window.
@MainActor
enum MainMenu {
    static func make(settingsTarget: AnyObject, settingsAction: Selector) -> NSMenu {
        let main = NSMenu()
        main.addItem(submenu(appMenu(settingsTarget: settingsTarget, settingsAction: settingsAction)))
        main.addItem(submenu(editMenu()))
        main.addItem(submenu(windowMenu()))
        return main
    }

    private static func appMenu(settingsTarget: AnyObject, settingsAction: Selector) -> NSMenu {
        let menu = NSMenu(title: "LingvoBuddy")
        let settings = NSMenuItem(title: String(localized: "Settings…"), action: settingsAction, keyEquivalent: ",")
        settings.target = settingsTarget
        menu.addItem(settings)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: String(localized: "Quit LingvoBuddy"),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        return menu
    }

    private static func editMenu() -> NSMenu {
        let menu = NSMenu(title: String(localized: "Edit"))
        menu.addItem(withTitle: String(localized: "Undo"), action: Selector(("undo:")), keyEquivalent: "z")
        let redo = menu.addItem(withTitle: String(localized: "Redo"), action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(.separator())
        menu.addItem(withTitle: String(localized: "Cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        menu.addItem(withTitle: String(localized: "Copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        menu.addItem(withTitle: String(localized: "Paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        menu.addItem(withTitle: String(localized: "Select All"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        return menu
    }

    private static func windowMenu() -> NSMenu {
        let menu = NSMenu(title: String(localized: "Window"))
        // Not `performClose:`: AppKit adds a hidden "Close All" ⌥⌘W alternate for it,
        // which takes the default "Show word now" hotkey away from the recorder.
        let close = menu.addItem(
            withTitle: String(localized: "Close"),
            action: #selector(WindowCommands.closeKeyWindow(_:)),
            keyEquivalent: "w"
        )
        close.target = WindowCommands.shared
        menu.addItem(withTitle: String(localized: "Minimize"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        return menu
    }

    private static func submenu(_ menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: menu.title, action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }
}

@MainActor
final class WindowCommands: NSObject {
    static let shared = WindowCommands()

    @objc func closeKeyWindow(_ sender: Any?) {
        NSApp.keyWindow?.performClose(sender)
    }
}
