import AppKit
import LingvoCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let openDelay: TimeInterval = 0.5

    private let errors = ErrorPresenter()
    private var statusItem: StatusItemController?
    private var coordinator: CardCoordinator?

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
        let tutor = try AppEnvironment.makeTutor(options: options)
        let focus = SystemFocusStatus()
        let coordinator = CardCoordinator(
            tutor: tutor,
            panel: CardPanelController(tutor: tutor, errors: errors),
            contexts: CardContextBuilder(
                quietHours: AppEnvironment.quietHours(options: options),
                focus: focus,
                fullScreen: FullScreenDetector(),
                pause: PauseStore()
            ),
            settings: try AppEnvironment.scheduleSettings(options: options),
            errors: errors
        )
        let statusItem = StatusItemController(actions: StatusItemActions(
            primaryClick: { [weak coordinator] in coordinator?.reopenWaitingCard() ?? false },
            showWordNow: { [weak coordinator] in coordinator?.showWordNow() },
            pause: { [weak coordinator] option in coordinator?.pause(option) },
            resume: { [weak coordinator] in coordinator?.resume() },
            pausedUntil: { [weak coordinator] in coordinator?.pausedUntil }
        ))
        coordinator.statusItem = statusItem
        self.coordinator = coordinator
        self.statusItem = statusItem
        HotKeys.register { [weak coordinator] in coordinator?.showWordNow() }
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

    private func open(_ view: OpenableView) {
        switch view {
        case .card:
            coordinator?.showWordNow()
        }
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
