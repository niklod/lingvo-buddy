import AppKit
import OSLog
import SwiftUI

/// The single Settings window. It is created on first use and kept, so a
/// second "Settings…" brings the same window forward.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let model: SettingsModel
    private let launchAtLogin: any LaunchAtLoginControlling
    private let about: AboutInfo
    private let errors: ErrorPresenter
    private let navigation = SettingsNavigation()
    private var window: NSWindow?
    private let logger = Logger(subsystem: "com.niklod.LingvoBuddy", category: "settings")

    init(model: SettingsModel, launchAtLogin: any LaunchAtLoginControlling, about: AboutInfo, errors: ErrorPresenter) {
        self.model = model
        self.launchAtLogin = launchAtLogin
        self.about = about
        self.errors = errors
        super.init()
    }

    var isShowing: Bool { window?.isVisible == true }

    func show(tab: SettingsTab? = nil) {
        if let tab {
            navigation.tab = tab
        }
        let window = window ?? makeWindow()
        self.window = window
        ForegroundWindows.show(window)
        logger.notice("settings shown, active: \(NSApp.isActive)")
    }

    func windowWillClose(_ notification: Notification) {
        guard let window else { return }
        ForegroundWindows.willClose(window)
    }

    private func makeWindow() -> NSWindow {
        let root = SettingsView(
            model: model,
            navigation: navigation,
            launchAtLogin: launchAtLogin,
            about: about,
            errors: errors
        )
        let host = NSHostingController(rootView: root)
        // The window follows the content height, which changes with the tab.
        host.sizingOptions = [.preferredContentSize]
        let window = NSWindow(contentViewController: host)
        window.title = String(localized: "LingvoBuddy Settings")
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor(Theme.Palette.panel)
        window.appearance = NSAppearance(named: .darkAqua)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        // Restores the last position, if there is one.
        window.setFrameAutosaveName("LingvoBuddySettings")
        return window
    }
}
