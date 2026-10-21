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
    private let transfer: CSVTransferActions
    private let navigation = SettingsNavigation()
    private var window: NSWindow?
    private let logger = Logger(subsystem: "com.niklod.LingvoBuddy", category: "settings")

    init(
        model: SettingsModel,
        launchAtLogin: any LaunchAtLoginControlling,
        about: AboutInfo,
        errors: ErrorPresenter,
        transfer: CSVTransferActions
    ) {
        self.model = model
        self.launchAtLogin = launchAtLogin
        self.about = about
        self.errors = errors
        self.transfer = transfer
        super.init()
    }

    var isShowing: Bool { window?.isVisible == true }

    func show(tab: SettingsTab? = nil) {
        if let tab {
            navigation.tab = tab
        }
        let window = window ?? makeWindow()
        self.window = window
        // An accessory (menu-bar) app may not take activation on macOS 14+, so the
        // window would open inactive behind other apps. A regular app may; the
        // Dock icon shows only while Settings is open (see windowWillClose).
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        logger.notice("settings shown, active: \(NSApp.isActive)")
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    private func makeWindow() -> NSWindow {
        let root = SettingsView(
            model: model,
            navigation: navigation,
            launchAtLogin: launchAtLogin,
            about: about,
            errors: errors,
            transfer: transfer
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
