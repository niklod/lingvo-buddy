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
        requestAccess { _ in }
    }
}

extension SystemFocusStatus: FocusAccessRequesting {
    var access: FocusAccess {
        guard isAvailable else { return .unavailable }
        return Self.access(for: INFocusStatusCenter.default.authorizationStatus)
    }

    func requestAccess(_ answered: @escaping @MainActor (FocusAccess) -> Void) {
        let current = access
        guard current == .notAsked else {
            logger.info("Focus status access: \(String(describing: current), privacy: .public)")
            answered(current)
            return
        }
        let logger = logger
        // Intents calls back on its own queue. Without @Sendable the closure would
        // inherit this class's main-actor isolation, and Swift 6 traps when it
        // runs off the main thread; the hop to main is explicit instead.
        INFocusStatusCenter.default.requestAuthorization { @Sendable status in
            logger.notice("Focus status authorization answered: \(status.rawValue)")
            let access = SystemFocusStatus.access(for: status)
            Task { @MainActor in answered(access) }
        }
    }

    private nonisolated static func access(for status: INFocusStatusAuthorizationStatus) -> FocusAccess {
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
