import AppKit
import LingvoCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// macOS refuses activation, and the status item has no frame, until launch finishes.
    private static let afterLaunchDelay: Duration = .milliseconds(500)

    private let errors = ErrorPresenter()
    private var statusItem: StatusItemController?
    private var coordinator: CardCoordinator?
    private var settingsWindow: SettingsWindowController?
    private var tray: TrayMenuController?
    private var quickAdd: QuickAddController?
    private var dictionaryWindow: DictionaryWindowController?
    private var csvTransfer: CSVTransferController?
    /// AppKit keeps only a weak reference to `servicesProvider`.
    private var services: ServiceProvider?
    private var onboarding: OnboardingWindowController?
    private var showOnboarding: (() -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
        do {
            let options = try LaunchOptions.parse(CommandLine.arguments)
            #if DEBUG
            if QALaunchModes.takeOver(options) { return }
            #endif
            try start(with: options)
        } catch {
            failLaunch(error)
        }
    }

    /// Scripts and agents start the binary directly and read stderr and the exit code;
    /// a modal alert would block them. Finder and `open` launches (parent launchd) get the alert.
    private func failLaunch(_ error: Error) -> Never {
        FileHandle.standardError.write(Data("LingvoBuddy: \(error.localizedDescription)\n".utf8))
        if getppid() == 1 {
            errors.show(error)
        }
        exit(EXIT_FAILURE)
    }

    private func start(with options: LaunchOptions) throws {
        let services = try AppEnvironment.makeServices(options: options)
        let tutor = services.tutor
        let settings = SettingsModel(store: tutor, errors: errors)
        let focus = SystemFocusStatus()
        let launchAtLogin = SystemLaunchAtLogin()
        let quickAdd = QuickAddController(tutor: tutor)
        makeWindows(tutor: tutor, settings: settings, launchAtLogin: launchAtLogin, services: services, quickAdd: quickAdd)
        let coordinator = try makeCoordinator(tutor: tutor, settings: settings, focus: focus, options: options)
        let tray = TrayMenuController(
            tutor: tutor,
            commands: trayCommands(for: coordinator, quickAdd: quickAdd),
            errors: errors
        )
        makeStatusItem(coordinator: coordinator, tray: tray)
        registerHotKeys(coordinator: coordinator, tray: tray, quickAdd: quickAdd)
        registerServices(quickAdd: quickAdd, tray: tray)
        self.coordinator = coordinator
        self.tray = tray
        self.quickAdd = quickAdd
        showOnboarding = { [weak self] in
            self?.presentOnboarding(tutor: tutor, settings: settings, focus: focus, launchAtLogin: launchAtLogin)
        }
        coordinator.start()
        try scheduleLaunchViews(options: options, tutor: tutor, focus: focus)
    }

    private func makeWindows(
        tutor: Tutor,
        settings: SettingsModel,
        launchAtLogin: SystemLaunchAtLogin,
        services: AppEnvironment.Services,
        quickAdd: QuickAddController
    ) {
        let csvTransfer = CSVTransferController(store: tutor, errors: errors)
        self.csvTransfer = csvTransfer
        settingsWindow = SettingsWindowController(
            model: settings,
            launchAtLogin: launchAtLogin,
            about: AboutInfo.current(dictionaryMeta: services.dictionaryMeta, extendedMeta: services.extendedMeta),
            errors: errors,
            transfer: csvTransfer.actions
        )
        dictionaryWindow = DictionaryWindowController(
            model: DictionaryModel(store: tutor, errors: errors),
            settings: settings,
            actions: DictionaryActions(addWord: { [weak quickAdd] prefill in quickAdd?.open(prefill: prefill) })
        )
        NSApp.mainMenu = MainMenu.make(
            target: self,
            settingsAction: #selector(openSettingsFromMenu),
            dictionaryAction: #selector(openDictionaryFromMenu)
        )
    }

    private func makeCoordinator(
        tutor: Tutor,
        settings: SettingsModel,
        focus: SystemFocusStatus,
        options: LaunchOptions
    ) throws -> CardCoordinator {
        CardCoordinator(
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
    }

    /// The tray and a card hang in the same place under the icon, so one gives way to the other.
    private func makeStatusItem(coordinator: CardCoordinator, tray: TrayMenuController) {
        let statusItem = StatusItemController(actions: StatusItemActions(
            primaryClick: { [weak coordinator, weak tray] in
                guard coordinator?.reopenWaitingCard() == true else { return false }
                tray?.close()
                return true
            },
            toggleTray: { [weak coordinator, weak tray] button in
                if tray?.isShowing == false {
                    coordinator?.setAsideShownCard()
                }
                tray?.toggle(under: button)
            }
        ))
        coordinator.statusItem = statusItem
        coordinator.isTrayOpen = { [weak tray] in tray?.isShowing == true }
        self.statusItem = statusItem
    }

    private func registerHotKeys(coordinator: CardCoordinator, tray: TrayMenuController, quickAdd: QuickAddController) {
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
            schedule: { [weak coordinator] in coordinator?.trayInfo ?? .idle },
            changeInterval: { [weak coordinator] interval in coordinator?.changeInterval(interval) },
            pause: { [weak coordinator] option in coordinator?.pause(option) },
            resume: { [weak coordinator] in coordinator?.resume() },
            quickAdd: { [weak quickAdd] text in quickAdd?.open(prefill: text) },
            openDictionary: { [weak self] in self?.openDictionary() },
            openSettings: { [weak self] in self?.openSettings() }
        )
    }

    private func scheduleLaunchViews(options: LaunchOptions, tutor: Tutor, focus: SystemFocusStatus) throws {
        if try !options.skipOnboarding && tutor.needsOnboarding() {
            // The Focus prompt is one of the onboarding steps; it must not pop up before it.
            afterLaunch { $0.showOnboarding?() }
        } else {
            focus.requestAccessIfNeeded()
        }
        if let view = options.openView {
            afterLaunch { $0.open(view, options: options) }
        }
    }

    private func afterLaunch(_ action: @escaping @MainActor (AppDelegate) -> Void) {
        Task { [weak self] in
            try? await Task.sleep(for: Self.afterLaunchDelay)
            guard let self else { return }
            action(self)
        }
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
}
