import Intents
import OSLog
import Security

@MainActor
protocol FocusStatusReading {
    /// `false` when the state is unknown (no permission, no entitlement).
    var isFocusOn: Bool { get }
    func requestAccessIfNeeded()
}

/// Reads the Focus state with `INFocusStatusCenter`.
///
/// The API needs the restricted Communication Notifications entitlement, which an
/// ad-hoc signed build cannot carry (the app would not launch). Without it the
/// API can crash, so this reader checks the signed entitlement first and
/// otherwise reports "not focused".
@MainActor
final class SystemFocusStatus: FocusStatusReading {
    static let entitlement = "com.apple.developer.usernotifications.communication"

    private let logger = Logger(subsystem: "com.niklod.LingvoBuddy", category: "focus")
    private let isAvailable = SystemFocusStatus.hasEntitlement()

    var isFocusOn: Bool {
        guard isAvailable else { return false }
        return INFocusStatusCenter.default.focusStatus.isFocused ?? false
    }

    func requestAccessIfNeeded() {
        guard isAvailable else {
            logger.notice("Focus status is off: the build has no \(Self.entitlement, privacy: .public) entitlement")
            return
        }
        let center = INFocusStatusCenter.default
        guard center.authorizationStatus == .notDetermined else {
            logger.info("Focus status authorization: \(center.authorizationStatus.rawValue)")
            return
        }
        let logger = logger
        center.requestAuthorization { status in
            logger.info("Focus status authorization answered: \(status.rawValue)")
        }
    }
}

extension SystemFocusStatus: FocusAccessRequesting {
    var access: FocusAccess {
        guard isAvailable else { return .unavailable }
        return Self.access(for: INFocusStatusCenter.default.authorizationStatus)
    }

    func requestAccess(_ answered: @escaping @MainActor (FocusAccess) -> Void) {
        guard access == .notAsked else {
            answered(access)
            return
        }
        let logger = logger
        INFocusStatusCenter.default.requestAuthorization { status in
            logger.notice("Focus status authorization answered: \(status.rawValue)")
            Task { @MainActor in answered(Self.access(for: status)) }
        }
    }

    private static func access(for status: INFocusStatusAuthorizationStatus) -> FocusAccess {
        switch status {
        case .authorized: .allowed
        case .denied, .restricted: .denied
        case .notDetermined: .notAsked
        @unknown default: .denied
        }
    }

    private static func hasEntitlement() -> Bool {
        guard let task = SecTaskCreateFromSelf(nil) else { return false }
        let value = SecTaskCopyValueForEntitlement(task, entitlement as CFString, nil)
        return (value as? Bool) == true
    }
}
