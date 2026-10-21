import AppKit
import LingvoCore
import OSLog

/// What the tray menu can ask the rest of the app to do.
struct TrayCommands {
    var showWordNow: () -> Void = {}
    var schedule: () -> TrayScheduleInfo = {
        TrayScheduleInfo(nextCardAt: nil, interval: CardScheduleSettings.defaultInterval, pausedUntil: nil)
    }
    var changeInterval: (TimeInterval) -> Void = { _ in }
    var pause: (PauseOption) -> Void = { _ in }
    var resume: () -> Void = {}
    /// Opens quick add prefilled with the inline field's text.
    var quickAdd: (String) -> Void = { _ in }
    /// `nil` greys the item out.
    var openDictionary: (() -> Void)?
    /// `nil` until the Settings slice lands; the item is then greyed out.
    var openSettings: (() -> Void)?
}

/// Opens the tray menu under the status item, keeps it fresh, and closes it on
/// an outside click, Esc, or after an item ran.
@MainActor
final class TrayMenuController {
    private let tutor: Tutor
    private let commands: TrayCommands
    private let errors: ErrorPresenter
    private let logger = Logger(subsystem: "com.niklod.LingvoBuddy", category: "tray")
    private var panel: TrayPanel?
    private var outsideClickMonitor: Any?
    private var appSwitchObserver: NSObjectProtocol?
    private weak var anchor: NSStatusBarButton?

    init(tutor: Tutor, commands: TrayCommands, errors: ErrorPresenter) {
        self.tutor = tutor
        self.commands = commands
        self.errors = errors
    }

    var isShowing: Bool { panel?.isVisible == true }

    func toggle(under anchor: NSStatusBarButton?) {
        if isShowing {
            close()
        } else {
            open(under: anchor)
        }
    }

    func open(under anchor: NSStatusBarButton?) {
        close()
        let state: TrayMenuState
        do {
            state = try currentState()
        } catch {
            errors.show(error)
            return
        }
        let panel = TrayPanel()
        panel.setContent(TrayMenuView(state: state, actions: actions, highlighted: nil) {
            TrayAddWordField { [weak self] text in self?.run { $0.commands.quickAdd(text) } }
        })
        panel.onKey = { [weak self] command in self?.handle(command) ?? false }
        panel.setFrameOrigin(CardPlacement.origin(for: panel.frame.size, under: anchor))
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
        self.anchor = anchor
        anchor?.highlight(true)
        watchForDismissal()
        logger.notice("tray menu opened")
    }

    func close() {
        guard let panel else { return }
        panel.orderOut(nil)
        self.panel = nil
        anchor?.highlight(false)
        stopWatching()
    }

    private func currentState() throws -> TrayMenuState {
        TrayMenuState(
            stats: try tutor.stats(),
            schedule: commands.schedule(),
            now: Date(),
            canOpenDictionary: commands.openDictionary != nil,
            canOpenSettings: commands.openSettings != nil
        )
    }

    private var actions: TrayMenuActions {
        TrayMenuActions(
            showWordNow: { [weak self] in self?.run { $0.commands.showWordNow() } },
            chooseInterval: { [weak self] in self?.chooseInterval() },
            choosePause: { [weak self] in self?.choosePause() },
            resume: { [weak self] in self?.run { $0.commands.resume() } },
            openDictionary: { [weak self] in self?.run { $0.commands.openDictionary?() } },
            openSettings: { [weak self] in self?.run { $0.commands.openSettings?() } },
            quit: { NSApp.terminate(nil) }
        )
    }

    /// Like a native menu, the tray closes before the chosen item runs.
    private func run(_ command: (TrayMenuController) -> Void) {
        close()
        command(self)
    }

    private func chooseInterval() {
        let menu = TraySubmenus.intervals(current: commands.schedule().interval) { [weak self] interval in
            self?.run { $0.commands.changeInterval(interval) }
        }
        TraySubmenus.popUp(menu, beside: panel?.frame)
    }

    private func choosePause() {
        let menu = TraySubmenus.pause { [weak self] option in
            self?.run { $0.commands.pause(option) }
        }
        TraySubmenus.popUp(menu, beside: panel?.frame)
    }

    private func handle(_ command: TrayKeyCommand) -> Bool {
        switch command {
        case .close:
            close()
        case .openDictionary:
            guard let open = commands.openDictionary else { return false }
            run { _ in open() }
        case .openSettings:
            guard let open = commands.openSettings else { return false }
            run { _ in open() }
        case .quit:
            NSApp.terminate(nil)
        }
        return true
    }

    /// Clicks in other apps reach only a global monitor (no permission needed
    /// for mouse events); switching apps with ⌘⇥ also closes the menu.
    private func watchForDismissal() {
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
            [weak self] _ in
            MainActor.assumeIsolated { self?.closeUnlessOnIcon() }
        }
        appSwitchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }
    }

    /// The menu bar hosts the status item outside the app, so a click on the
    /// icon also reaches the global monitor. Closing here would make the icon's
    /// own toggle reopen the menu at once.
    private func closeUnlessOnIcon() {
        if let anchor, let window = anchor.window {
            let iconFrame = window.convertToScreen(anchor.convert(anchor.bounds, to: nil))
            if iconFrame.contains(NSEvent.mouseLocation) { return }
        }
        close()
    }

    private func stopWatching() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
        }
        if let appSwitchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(appSwitchObserver)
        }
        outsideClickMonitor = nil
        appSwitchObserver = nil
    }
}
