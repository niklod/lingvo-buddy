import AppKit
import LingvoCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let openDelay: TimeInterval = 0.5

    private let errors = ErrorPresenter()
    private var statusItem: StatusItemController?
    private var cardPanel: CardPanelController?

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
        let cardPanel = CardPanelController(tutor: tutor, errors: errors)
        let statusItem = StatusItemController { [weak self] in self?.showWordNow() }
        self.cardPanel = cardPanel
        self.statusItem = statusItem
        if let view = options.openView {
            // The status item gets its place in the menu bar only after launch
            // finishes; opening earlier would anchor the card to a zero frame.
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.openDelay) { [weak self] in
                self?.open(view)
            }
        }
    }

    private func showWordNow() {
        cardPanel?.showNextCard(under: statusItem?.anchor)
    }

    private func open(_ view: OpenableView) {
        switch view {
        case .card:
            showWordNow()
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
