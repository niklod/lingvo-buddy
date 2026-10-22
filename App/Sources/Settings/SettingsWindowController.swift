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
            errors: errors,
            transfer: transfer
        )
        // The default sizing makes the window follow the content height, which changes with the tab.
        let window = NSWindow.themed(
            root,
            title: String(localized: "LingvoBuddy Settings"),
            style: [.titled, .closable, .miniaturizable],
            autosaveName: "LingvoBuddySettings"
        )
        window.delegate = self
        return window
    }
}
