import AppKit
import LingvoCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let openDelay: TimeInterval = 0.5

    private let errors = ErrorPresenter()
    private var statusItem: StatusItemController?
    private var coordinator: CardCoordinator?
    private var settingsWindow: SettingsWindowController?
    private var tray: TrayMenuController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
        do {
            let options = try LaunchOptions.parse(CommandLine.arguments)
            if let directory = options.snapshotDirectory {
                renderSnapshotsAndExit(to: directory, filter: options.snapshotFilter)
            }
            try start(with: options)
        } catch {
            errors.show(error)
            NSApp.terminate(nil)
        }
    }

    private func start(with options: LaunchOptions) throws {
        let services = try AppEnvironment.makeServices(options: options)
        let tutor = services.tutor
        let settings = SettingsModel(store: tutor, errors: errors)
        settingsWindow = SettingsWindowController(
            model: settings,
            launchAtLogin: SystemLaunchAtLogin(),
            about: AboutInfo.current(dictionaryMeta: services.dictionaryMeta),
            errors: errors
        )
        NSApp.mainMenu = MainMenu.make(settingsTarget: self, settingsAction: #selector(openSettingsFromMenu))
        let focus = SystemFocusStatus()
        let coordinator = CardCoordinator(
            tutor: tutor,
            panel: CardPanelController(tutor: tutor, errors: errors),
            contexts: CardContextBuilder(
                settings: settings,
                quietHoursOverride: options.quietHours,
                focus: focus,
                fullScreen: FullScreenDetector(),
                pause: PauseStore()
            ),
            scheduleSettings: try AppEnvironment.scheduleSettings(options: options, settings: settings.settings),
            errors: errors
        )
        let tray = TrayMenuController(tutor: tutor, commands: trayCommands(for: coordinator), errors: errors)
        let statusItem = StatusItemController(actions: StatusItemActions(
            primaryClick: { [weak coordinator, weak tray] in
                guard coordinator?.reopenWaitingCard() == true else { return false }
                tray?.close()
                return true
            },
            toggleTray: { [weak tray] button in tray?.toggle(under: button) }
        ))
        coordinator.statusItem = statusItem
        self.coordinator = coordinator
        self.statusItem = statusItem
        self.tray = tray
        HotKeys.register { [weak coordinator, weak tray] in
            tray?.close()
            coordinator?.showWordNow()
        }
        focus.requestAccessIfNeeded()
        coordinator.start()
        if let view = options.openView {
            // The status item gets its place in the menu bar only after launch
            // finishes; opening earlier would anchor the card to a zero frame.
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.openDelay) { [weak self] in
                self?.open(view)
            }
        }
    }

    /// Settings (#22) and the Dictionary window set their entry points here.
    private func trayCommands(for coordinator: CardCoordinator) -> TrayCommands {
        TrayCommands(
            showWordNow: { [weak coordinator] in coordinator?.showWordNow() },
            schedule: { [weak coordinator] in
                coordinator?.trayInfo
                    ?? TrayScheduleInfo(nextCardAt: nil, interval: CardScheduleSettings.defaultInterval, pausedUntil: nil)
            },
            changeInterval: { [weak coordinator] interval in coordinator?.changeInterval(interval) },
            pause: { [weak coordinator] option in coordinator?.pause(option) },
            resume: { [weak coordinator] in coordinator?.resume() },
            openDictionary: nil,
            openSettings: { [weak self] in self?.openSettings() }
        )
    }

    private func open(_ view: OpenableView) {
        switch view {
        case .card:
            coordinator?.showWordNow()
        case .tray:
            tray?.open(under: statusItem?.anchor)
        case .settings:
            openSettings(tab: .general)
        case .about:
            openSettings(tab: .about)
        }
    }

    /// The single entry point to Settings: tray item "Settings… ⌘,", the ⌘, key, `--open settings`.
    func openSettings(tab: SettingsTab? = nil) {
        settingsWindow?.show(tab: tab)
    }

    @objc private func openSettingsFromMenu() {
        openSettings()
    }

    private func renderSnapshotsAndExit(to path: String, filter: String?) -> Never {
        let states = SnapshotRegistry.all.filter { filter == nil || $0.name.contains(filter ?? "") }
        do {
            let files = try SnapshotRenderer.render(states, to: SnapshotRenderer.directoryURL(path))
            files.forEach { print($0.path) }
            exit(0)
        } catch {
            FileHandle.standardError.write(Data("snapshot failed: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }
}
