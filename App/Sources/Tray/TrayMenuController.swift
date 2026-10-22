import AppKit
import LingvoCore
import OSLog

/// What the tray menu can ask the rest of the app to do.
struct TrayCommands {
    let showWordNow: () -> Void
    let schedule: () -> TrayScheduleInfo
    let changeInterval: (TimeInterval) -> Void
    let pause: (PauseOption) -> Void
    let resume: () -> Void
    /// Opens quick add prefilled with the inline field's text.
    let quickAdd: (String) -> Void
    let openDictionary: () -> Void
    let openSettings: () -> Void
}

/// Opens the tray menu under the status item with the stats of that moment,
/// and closes it on an outside click, Esc, or after an item ran.
@MainActor
final class TrayMenuController {
    private let tutor: Tutor
    private let commands: TrayCommands
    private let errors: ErrorPresenter
    private let clock: any TutorClock
    private let logger = Logger.app(category: "tray")
    private var panel: TrayPanel?
    private var outsideClickMonitor: Any?
    private var appSwitchObserver: NSObjectProtocol?
    private weak var anchor: NSStatusBarButton?

    init(tutor: Tutor, commands: TrayCommands, errors: ErrorPresenter, clock: any TutorClock = SystemClock()) {
        self.tutor = tutor
        self.commands = commands
        self.errors = errors
        self.clock = clock
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
        let quickAdd = commands.quickAdd
        panel.setContent(TrayMenuView(state: state, actions: actions, highlighted: nil) { [weak self] in
            TrayAddWordField { text in self?.run { quickAdd(text) } }
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
        TrayMenuState(stats: try tutor.stats(), schedule: commands.schedule(), now: clock.now())
    }

    private var actions: TrayMenuActions {
        let commands = commands
        return TrayMenuActions(
            showWordNow: { [weak self] in self?.run(commands.showWordNow) },
            chooseInterval: { [weak self] in self?.chooseInterval() },
            choosePause: { [weak self] in self?.choosePause() },
            resume: { [weak self] in self?.run(commands.resume) },
            openDictionary: { [weak self] in self?.run(commands.openDictionary) },
            openSettings: { [weak self] in self?.run(commands.openSettings) },
            quit: { NSApp.terminate(nil) }
        )
    }

    /// Like a native menu, the tray closes before the chosen item runs.
    private func run(_ command: () -> Void) {
        close()
        command()
    }

    private func chooseInterval() {
        let changeInterval = commands.changeInterval
        let menu = TraySubmenus.intervals(current: commands.schedule().interval) { [weak self] interval in
            self?.run { changeInterval(interval) }
        }
        TraySubmenus.popUp(menu, beside: panel?.frame)
    }

    private func choosePause() {
        let pause = commands.pause
        let menu = TraySubmenus.pause { [weak self] option in
            self?.run { pause(option) }
        }
        TraySubmenus.popUp(menu, beside: panel?.frame)
    }

    private func handle(_ command: TrayKeyCommand) -> Bool {
        switch command {
        case .close:
            close()
        case .openDictionary:
            run(commands.openDictionary)
        case .openSettings:
            run(commands.openSettings)
        case .quit:
            NSApp.terminate(nil)
        }
        return true
    }

    /// Clicks in other apps reach only a global monitor (no permission needed
    /// for mouse events); switching apps with ⌘⇥ also closes the menu.
    private func watchForDismissal() {
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
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
