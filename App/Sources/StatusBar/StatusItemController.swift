import AppKit

/// The "Aa" status item. Until the tray menu slice, a click opens a small menu.
@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let showWordNow: () -> Void

    init(showWordNow: @escaping () -> Void) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.showWordNow = showWordNow
        super.init()
        statusItem.button?.image = StatusGlyph.image()
        statusItem.button?.setAccessibilityTitle("LingvoBuddy")
        statusItem.menu = makeMenu()
    }

    var anchor: NSStatusBarButton? { statusItem.button }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        let show = NSMenuItem(
            title: String(localized: "Show word now"),
            action: #selector(showWordNowClicked),
            keyEquivalent: "w"
        )
        show.keyEquivalentModifierMask = [.option, .command]
        show.target = self
        menu.addItem(show)
        menu.addItem(.separator())
        let quit = NSMenuItem(
            title: String(localized: "Quit"),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quit)
        return menu
    }

    @objc private func showWordNowClicked() {
        showWordNow()
    }
}
