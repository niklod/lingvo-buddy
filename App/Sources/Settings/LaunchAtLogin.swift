import Foundation
import OSLog
import ServiceManagement

/// What the Settings window shows for "Launch at login".
enum LaunchAtLoginState: Equatable {
    case off
    case on
    /// Registered, but the learner must allow it in System Settings > Login Items.
    case needsApproval
}

@MainActor
protocol LaunchAtLoginControlling: AnyObject {
    /// Read fresh each time: the learner can change it in System Settings at any moment.
    var state: LaunchAtLoginState { get }
    func setEnabled(_ enabled: Bool) throws
    func openSystemSettings()
}

/// The login item through `SMAppService.mainApp`: no helper app, sandbox-safe.
/// App Store rule 2.4.5(iii): register only after the learner turns the toggle on.
@MainActor
final class SystemLaunchAtLogin: LaunchAtLoginControlling {
    private let logger = Logger(subsystem: "com.niklod.LingvoBuddy", category: "settings")

    var state: LaunchAtLoginState {
        switch SMAppService.mainApp.status {
        case .enabled: .on
        case .requiresApproval: .needsApproval
        case .notRegistered, .notFound: .off
        @unknown default: .off
        }
    }

    func setEnabled(_ enabled: Bool) throws {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            logger.notice("launch at login \(enabled ? "on" : "off", privacy: .public): \(String(describing: self.state), privacy: .public)")
        } catch {
            logger.error("launch at login change failed: \(String(describing: error), privacy: .public)")
            throw LaunchAtLoginError.changeFailed(enabled: enabled, underlying: error.localizedDescription)
        }
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

enum LaunchAtLoginError: Error, LocalizedError {
    case changeFailed(enabled: Bool, underlying: String)

    var errorDescription: String? {
        switch self {
        case .changeFailed(let enabled, let underlying):
            enabled
                ? String(localized: "LingvoBuddy could not add itself to the login items. \(underlying)")
                : String(localized: "LingvoBuddy could not remove itself from the login items. \(underlying)")
        }
    }
}

/// A fixed state for snapshots, so they never read or change the real login item.
@MainActor
final class FixedLaunchAtLogin: LaunchAtLoginControlling {
    private(set) var state: LaunchAtLoginState

    init(_ state: LaunchAtLoginState) {
        self.state = state
    }

    func setEnabled(_ enabled: Bool) throws {
        state = enabled ? .on : .off
    }

    func openSystemSettings() {}
}
