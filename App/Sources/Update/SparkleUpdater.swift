import Foundation
import LingvoCore
import OSLog
import Sparkle

/// Owns Sparkle's updater for the app's lifetime. Info.plist holds the feed, the EdDSA key and
/// the 6-hour schedule; this adds the check at launch and connects the update button.
@MainActor
final class SparkleUpdater: NSObject, SPUUpdaterDelegate {
    private static let logger = Logger.app(category: "update")

    private let center: UpdateCenter
    private let driver: SparkleUserDriver
    private var updater: SPUUpdater?

    private init(center: UpdateCenter) {
        self.center = center
        driver = SparkleUserDriver(center: center)
        super.init()
    }

    /// Nil in Debug builds and in dev builds (`0.0.0-dev.N`), which never check and never install,
    /// and when Sparkle did not start.
    static func startIfRelease(center: UpdateCenter, bundle: Bundle = .main) -> SparkleUpdater? {
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        guard isReleaseBuild, UpdaterGate.allows(shortVersion: version) else {
            logger.notice("updater off for version \(version, privacy: .public)")
            return nil
        }
        let controller = SparkleUpdater(center: center)
        return controller.start(bundle: bundle) ? controller : nil
    }

    private static var isReleaseBuild: Bool {
        #if DEBUG
        false
        #else
        true
        #endif
    }

    private func start(bundle: Bundle) -> Bool {
        let updater = SPUUpdater(hostBundle: bundle, applicationBundle: bundle, userDriver: driver, delegate: self)
        do {
            try updater.start()
        } catch {
            Self.logger.error("Sparkle did not start: \(error as NSError, privacy: .public)")
            return false
        }
        self.updater = updater
        // Sparkle drops a check while a session runs; the driver then waits for the session's end.
        driver.checkForUpdates = { [weak updater] in
            guard let updater, !updater.sessionInProgress else { return false }
            updater.checkForUpdates()
            return true
        }
        center.onInstallRequested = { [weak driver] in driver?.install() }
        // Sparkle's own schedule skips a launch within 6 hours of the last check; the spec wants one.
        if updater.automaticallyChecksForUpdates {
            updater.checkForUpdatesInBackground()
        }
        return true
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        center.send(.foundNothing)
    }

    // Also "nothing found" (SUNoUpdateError). The driver hears of failures only in sessions that
    // showed an update, so a failed scheduled check leaves the tray as it is, unless a click
    // waits for it (`sessionEnded`).
    func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
        Self.logger.notice("update cycle aborted: \(error as NSError, privacy: .public)")
    }

    // Every session ends here, also one that dropped the learner's click.
    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
        driver.sessionEnded(error: error)
    }
}
