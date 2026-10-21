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
    private var quickAdd: QuickAddController?
    private var dictionaryWindow: DictionaryWindowController?
    /// AppKit keeps only a weak reference to `servicesProvider`.
    private var services: ServiceProvider?
    private var onboarding: OnboardingWindowController?
    private var showOnboarding: (() -> Void)?

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
        let launchAtLogin = SystemLaunchAtLogin()
        settingsWindow = SettingsWindowController(
            model: settings,
            launchAtLogin: launchAtLogin,
            about: AboutInfo.current(dictionaryMeta: services.dictionaryMeta),
            errors: errors
        )
        NSApp.mainMenu = MainMenu.make(
            target: self,
            settingsAction: #selector(openSettingsFromMenu),
            dictionaryAction: #selector(openDictionaryFromMenu)
        )
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
        let quickAdd = QuickAddController(tutor: tutor)
        dictionaryWindow = DictionaryWindowController(
            model: DictionaryModel(store: tutor, errors: errors),
            settings: settings,
            actions: DictionaryActions(addWord: { [weak quickAdd] prefill in quickAdd?.open(prefill: prefill) })
        )
        let tray = TrayMenuController(
            tutor: tutor,
            commands: trayCommands(for: coordinator, quickAdd: quickAdd),
            errors: errors
        )
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
        self.quickAdd = quickAdd
        HotKeys.register(
            showWordNow: { [weak coordinator, weak tray] in
                tray?.close()
                coordinator?.showWordNow()
            },
            quickAdd: { [weak quickAdd, weak tray] in
                tray?.close()
                quickAdd?.open()
            }
        )
        registerServices(quickAdd: quickAdd, tray: tray)
        showOnboarding = { [weak self] in
            self?.presentOnboarding(tutor: tutor, settings: settings, focus: focus, launchAtLogin: launchAtLogin)
        }
        coordinator.start()
        if try !options.skipOnboarding && tutor.needsOnboarding() {
            // The Focus prompt is one of the onboarding steps; it must not pop up before it.
            // Shown after launch finishes: macOS refuses activation earlier.
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.openDelay) { [weak self] in
                self?.showOnboarding?()
            }
        } else {
            focus.requestAccessIfNeeded()
        }
        if let view = options.openView {
            // The status item gets its place in the menu bar only after launch
            // finishes; opening earlier would anchor the card to a zero frame.
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.openDelay) { [weak self] in
                self?.open(view, options: options)
            }
        }
    }

    private func registerServices(quickAdd: QuickAddController, tray: TrayMenuController) {
        let services = ServiceProvider { [weak quickAdd, weak tray] word, example in
            tray?.close()
            quickAdd?.open(prefill: word, example: example)
        }
        NSApp.servicesProvider = services
        // Picks up the Services item of a freshly built or moved app.
        NSUpdateDynamicServices()
        self.services = services
    }

    private func trayCommands(for coordinator: CardCoordinator, quickAdd: QuickAddController) -> TrayCommands {
        TrayCommands(
            showWordNow: { [weak coordinator] in coordinator?.showWordNow() },
            schedule: { [weak coordinator] in
                coordinator?.trayInfo
                    ?? TrayScheduleInfo(nextCardAt: nil, interval: CardScheduleSettings.defaultInterval, pausedUntil: nil)
            },
            changeInterval: { [weak coordinator] interval in coordinator?.changeInterval(interval) },
            pause: { [weak coordinator] option in coordinator?.pause(option) },
            resume: { [weak coordinator] in coordinator?.resume() },
            quickAdd: { [weak quickAdd] text in quickAdd?.open(prefill: text) },
            openDictionary: { [weak self] in self?.openDictionary() },
            openSettings: { [weak self] in self?.openSettings() }
        )
    }

    private func open(_ view: OpenableView, options: LaunchOptions) {
        switch view {
        case .card:
            coordinator?.showWordNow()
        case .tray:
            tray?.open(under: statusItem?.anchor)
        case .quickAdd:
            quickAdd?.open(prefill: options.prefill)
        case .settings:
            openSettings(tab: .general)
        case .about:
            openSettings(tab: .about)
        case .onboarding:
            showOnboarding?()
        case .dictionary:
            openDictionary()
        }
    }

    private func presentOnboarding(
        tutor: Tutor,
        settings: SettingsModel,
        focus: SystemFocusStatus,
        launchAtLogin: SystemLaunchAtLogin
    ) {
        if let onboarding {
            onboarding.show()
            return
        }
        let controller = OnboardingWindowController(
            model: OnboardingModel(store: tutor, errors: errors),
            settings: settings,
            focus: focus,
            launchAtLogin: launchAtLogin,
            errors: errors,
            onFinish: { [weak self] in
                // Released on the next turn: the controller is still on the call stack here.
                DispatchQueue.main.async { self?.onboarding = nil }
            }
        )
        onboarding = controller
        controller.show()
    }

    /// The single entry point to Settings: tray item "Settings… ⌘,", the ⌘, key, `--open settings`.
    func openSettings(tab: SettingsTab? = nil) {
        settingsWindow?.show(tab: tab)
    }

    @objc private func openSettingsFromMenu() {
        openSettings()
    }

    /// Tray item "Open Dictionary… ⌘D", the ⌘D key while one of our windows is key, `--open dictionary`.
    func openDictionary() {
        tray?.close()
        dictionaryWindow?.show()
    }

    @objc private func openDictionaryFromMenu() {
        openDictionary()
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
