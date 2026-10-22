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
    /// A change came while nobody could see the window: reload when it shows again.
    private var isStale = true
    private let logger = Logger(subsystem: "com.niklod.LingvoBuddy", category: "dictionary")

    init(model: DictionaryModel, settings: SettingsModel, actions: DictionaryActions) {
        self.model = model
        self.settings = settings
        self.actions = actions
        super.init()
        // Cards and quick add change words while the window stays open behind them.
        // A row action already reloaded the model that posted it.
        let modelID = ObjectIdentifier(model)
        changesObserver = NotificationCenter.default.addObserver(
            forName: UserDataChanges.notification, object: nil, queue: .main
        ) { [weak self] note in
            let isOwnChange = (note.object as AnyObject?).map(ObjectIdentifier.init) == modelID
            MainActor.assumeIsolated {
                if !isOwnChange { self?.reloadIfVisible() }
            }
        }
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        // Becoming key reloads; this covers a window that stays behind (refused activation).
        ForegroundWindows.show(window)
        if isStale {
            reload()
        }
        logger.notice("dictionary shown, active: \(NSApp.isActive)")
    }

    func windowDidBecomeKey(_ notification: Notification) {
        // The "12 min" ages move with the clock, so a return to the window refreshes them.
        reload()
    }

    func windowDidChangeOcclusionState(_ notification: Notification) {
        if isStale {
            reloadIfVisible()
        }
    }

    func windowWillClose(_ notification: Notification) {
        guard let window else { return }
        ForegroundWindows.willClose(window)
    }

    /// `isVisible` is also true for a window fully covered by others; only an
    /// unoccluded window is worth a full rebuild on each answer.
    private func reloadIfVisible() {
        guard let window, window.isVisible, window.occlusionState.contains(.visible) else {
            isStale = true
            return
        }
        reload()
    }

    private func reload() {
        model.reload()
        isStale = false
    }

    private func makeWindow() -> NSWindow {
        let root = DictionaryView(model: model, settings: settings, actions: actions)
            .frame(
                minWidth: DictionaryLayout.minimumSize.width, idealWidth: DictionaryLayout.windowSize.width,
                minHeight: DictionaryLayout.minimumSize.height, idealHeight: DictionaryLayout.windowSize.height
            )
        let window = NSWindow.themed(
            root,
            title: String(localized: "Dictionary"),
            style: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            sizing: [.minSize],
            hidesTitle: true,
            contentSize: DictionaryLayout.windowSize,
            autosaveName: "LingvoBuddyDictionary"
        )
        window.delegate = self
        return window
    }
}
