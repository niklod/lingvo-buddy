import LingvoCore
import OSLog
import Sparkle

/// Sparkle's UI, replaced by the tray header: each callback becomes one `UpdateCenter` event, and
/// no callback opens a window. Every reply block is called at once, except the final "install and
/// relaunch", which waits until "Restarting…" shows.
@MainActor
final class SparkleUserDriver: NSObject, SPUUserDriver {
    /// Sparkle quits the app before the next frame, so an instant reply never shows "Restarting…".
    private static let restartingVisibleFor: Duration = .milliseconds(700)

    private let center: UpdateCenter
    private let logger = Logger.app(category: "update")
    /// The learner clicked: the next session that finds an update installs it.
    private var installsNextFoundUpdate = false
    /// The wait before the "install and relaunch" reply. An aborted session cancels it.
    private var restartReply: Task<Void, Never>?
    private var download = DownloadProgress()

    /// Starts a user-initiated check. False when Sparkle would drop it because a session runs.
    var checkForUpdates: () -> Bool = { false }

    init(center: UpdateCenter) {
        self.center = center
    }

    /// The learner clicked the update button (install or Retry). The driver held no reply (that
    /// would keep the session open), so the click starts a new check that installs what it finds.
    func install() {
        installsNextFoundUpdate = true
        if !checkForUpdates() {
            logger.notice("install waits for the running session")
        }
    }

    /// The updater delegate's end of a session. A click that is still downloading got no update
    /// from it: run the click's own check, or fail so that the learner can Retry.
    func sessionEnded(error: (any Error)?) {
        let clickWaits = installsNextFoundUpdate
        installsNextFoundUpdate = false
        guard case .downloading = center.state else { return }
        // "Nothing found" already moved the state to idle through the updater delegate.
        if let error = error as NSError?, error.domain == SUSparkleErrorDomain,
           error.code == Int(SUError.noUpdateError.rawValue) {
            return
        }
        if clickWaits, error == nil {
            install()
            return
        }
        let reason = error.map(UpdateFailureReason.init) ?? .other
        logger.error("session ended during the download (\(String(describing: reason), privacy: .public))")
        center.send(.failed(reason))
    }

    func show(
        _ request: SPUUpdatePermissionRequest,
        reply: @escaping (SUUpdatePermissionResponse) -> Void
    ) {
        // Info.plist turns checks on, so Sparkle should never ask; answer as Info.plist says.
        logger.notice("Sparkle asked for check permission")
        reply(SUUpdatePermissionResponse(automaticUpdateChecks: true, sendSystemProfile: false))
    }

    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {}

    func showUpdateFound(
        with appcastItem: SUAppcastItem,
        state: SPUUserUpdateState,
        reply: @escaping (SPUUserUpdateChoice) -> Void
    ) {
        let version = appcastItem.displayVersionString
        logger.notice("update found: \(version, privacy: .public) (build \(appcastItem.versionString, privacy: .public))")
        guard !appcastItem.isInformationOnlyUpdate else {
            reply(.dismiss)
            return
        }
        center.send(.foundVersion(version))
        if installsNextFoundUpdate {
            installsNextFoundUpdate = false
            reply(.install)
        } else {
            // A held reply keeps the session open, and Sparkle schedules no next check while a
            // session runs: the button would offer this version forever.
            reply(.dismiss)
        }
    }

    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}

    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: any Error) {}

    // The updater delegate reports "nothing found" for scheduled and user-initiated checks alike.
    func showUpdateNotFoundWithError(_ error: any Error, acknowledgement: @escaping () -> Void) {
        acknowledgement()
    }

    func showUpdaterError(_ error: any Error, acknowledgement: @escaping () -> Void) {
        let reason = UpdateFailureReason(error: error)
        logger.error("update failed (\(String(describing: reason), privacy: .public)): \(error as NSError, privacy: .public)")
        center.send(.failed(reason))
        acknowledgement()
    }

    func showDownloadInitiated(cancellation: @escaping () -> Void) {
        download = DownloadProgress()
        center.send(.progress(0))
    }

    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
        download.expected = expectedContentLength
    }

    func showDownloadDidReceiveData(ofLength length: UInt64) {
        if let fraction = download.receive(length) {
            center.send(.progress(fraction))
        }
    }

    func showDownloadDidStartExtractingUpdate() {
        center.send(.progress(1))
    }

    func showExtractionReceivedProgress(_ progress: Double) {}

    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        logger.notice("update verified: installing and relaunching")
        center.send(.downloadVerified)
        restartReply?.cancel()
        restartReply = Task {
            try? await Task.sleep(for: Self.restartingVisibleFor)
            guard !Task.isCancelled else { return }
            restartReply = nil
            reply(.install)
        }
    }

    func showInstallingUpdate(
        withApplicationTerminated applicationTerminated: Bool,
        retryTerminatingApplication: @escaping () -> Void
    ) {
        logger.notice("installing update, app terminated: \(applicationTerminated)")
    }

    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
        acknowledgement()
    }

    /// Sparkle tore the session down: a pending "install and relaunch" reply goes to nothing now.
    func dismissUpdateInstallation() {
        restartReply?.cancel()
        restartReply = nil
    }
}

/// Bytes received against the expected length. Sparkle reports every chunk; the tray needs
/// a new value only when the shown percent changes.
private struct DownloadProgress {
    var expected: UInt64 = 0
    private var received: UInt64 = 0
    private var shownPercent = 0

    mutating func receive(_ length: UInt64) -> Double? {
        received += length
        guard expected > 0 else { return nil }
        let fraction = min(Double(received) / Double(expected), 1)
        let percent = Int((fraction * 100).rounded())
        guard percent != shownPercent else { return nil }
        shownPercent = percent
        return fraction
    }
}
