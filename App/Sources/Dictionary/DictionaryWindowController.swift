import AppKit
import OSLog
import SwiftUI

/// The single Dictionary window (⌘D, tray "Open Dictionary…", `--open dictionary`).
/// Created on first use and kept, so a second open brings the same window forward.
@MainActor
final class DictionaryWindowController: NSObject, NSWindowDelegate {
    private let model: DictionaryModel
    private let settings: SettingsModel
    private let actions: DictionaryActions
    private var window: NSWindow?
    private var changesObserver: NSObjectProtocol?
    private let logger = Logger(subsystem: "com.niklod.LingvoBuddy", category: "dictionary")

    init(model: DictionaryModel, settings: SettingsModel, actions: DictionaryActions) {
        self.model = model
        self.settings = settings
        self.actions = actions
        super.init()
        // Cards and quick add change words while the window stays open behind them.
        changesObserver = NotificationCenter.default.addObserver(
            forName: UserDataChanges.notification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reloadIfShowing() }
        }
    }

    var isShowing: Bool { window?.isVisible == true }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        model.reload()
        ForegroundWindows.show(window)
        logger.notice("dictionary shown, active: \(NSApp.isActive)")
    }

    func windowDidBecomeKey(_ notification: Notification) {
        // Onboarding or another window may have changed progress meanwhile.
        model.reload()
    }

    func windowWillClose(_ notification: Notification) {
        guard let window else { return }
        ForegroundWindows.willClose(window)
    }

    private func reloadIfShowing() {
        guard isShowing else { return }
        model.reload()
    }

    private func makeWindow() -> NSWindow {
        let root = DictionaryView(model: model, settings: settings, actions: actions)
            .frame(
                minWidth: DictionaryLayout.minimumSize.width, idealWidth: DictionaryLayout.windowSize.width,
                minHeight: DictionaryLayout.minimumSize.height, idealHeight: DictionaryLayout.windowSize.height
            )
        let host = NSHostingController(rootView: root)
        host.sizingOptions = [.minSize]
        let window = NSWindow(contentViewController: host)
        window.title = String(localized: "Dictionary")
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.backgroundColor = NSColor(Theme.Palette.panel)
        window.appearance = NSAppearance(named: .darkAqua)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setContentSize(DictionaryLayout.windowSize)
        window.center()
        // Restores the last size and position, if there are any.
        window.setFrameAutosaveName("LingvoBuddyDictionary")
        return window
    }
}
