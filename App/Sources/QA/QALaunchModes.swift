#if DEBUG
import AppKit

/// Launch modes that do one QA job and exit with its result: `--check-panel-sizes`
/// and `--snapshot`. Scripts read stderr and the exit code.
@MainActor
enum QALaunchModes {
    /// `true` when a QA mode took over this launch; the app then starts nothing else.
    static func takeOver(_ options: LaunchOptions) -> Bool {
        if options.checksPanelSizes {
            Task { await checkPanelSizesAndExit() }
            return true
        }
        if let directory = options.snapshotDirectory {
            Task { await renderSnapshotsAndExit(to: directory, filter: options.snapshotFilter) }
            return true
        }
        return false
    }

    private static func renderSnapshotsAndExit(to path: String, filter: String?) async -> Never {
        let states = SnapshotRegistry.all.filter { state in filter.map { state.name.contains($0) } ?? true }
        do {
            let files = try await SnapshotRenderer.render(states, to: SnapshotRenderer.directoryURL(path))
            files.forEach { print($0.path) }
            exit(0)
        } catch {
            FileHandle.standardError.write(Data("snapshot failed: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }

    private static func checkPanelSizesAndExit() async -> Never {
        let failures = await SnapshotRenderer.endlessPanels(SnapshotRegistry.all)
        guard failures.isEmpty else {
            failures.forEach { FileHandle.standardError.write(Data("endless panel size: \($0)\n".utf8)) }
            FileHandle.standardError.write(Data("See \"Panel content\" in docs/agents/macos-traps.md.\n".utf8))
            exit(1)
        }
        print("panel sizes OK")
        exit(0)
    }
}
#endif
