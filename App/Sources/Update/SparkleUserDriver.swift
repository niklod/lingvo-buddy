import LingvoCore
import OSLog
import Sparkle

/// Sparkle's UI, replaced by the tray header: each callback becomes one `UpdateCenter` event, and
/// no callback opens a window. The "update found" reply waits for the learner's click; once the
/// download is verified, the driver installs and relaunches with no confirmation.
@MainActor
final class SparkleUserDriver: NSObject, SPUUserDriver {
    /// Sparkle quits the app before the next frame, so an instant reply never shows "Restarting…".
    private static let restartingVisibleFor: Duration = .milliseconds(700)

    private let center: UpdateCenter
    private let logger = Logger.app(category: "update")
    private var heldInstallReply: ((SPUUserUpdateChoice) -> Void)?
    /// A click came with no held reply (Retry after a failure): install what the new check finds.
    private var installsNextFoundUpdate = false
    private var download = DownloadProgress()

    /// Starts a user-initiated check: Retry needs a new session after a failed one.
    var checkForUpdates: () -> Void = {}

    init(center: UpdateCenter) {
        self.center = center
    }

    /// The learner clicked the update button (install or Retry).
    func install() {
        if let reply = heldInstallReply {
            heldInstallReply = nil
            reply(.install)
        } else {
            installsNextFoundUpdate = true
            checkForUpdates()
        }
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
            heldInstallReply = reply
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
        Task {
            try? await Task.sleep(for: Self.restartingVisibleFor)
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

    /// The session ended (after an error, "nothing found", or an abort): a held reply is dead now.
    func dismissUpdateInstallation() {
        heldInstallReply = nil
        installsNextFoundUpdate = false
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
