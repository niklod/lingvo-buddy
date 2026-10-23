import Foundation

/// Why an update failed. The tray shows one short line per reason.
public enum UpdateFailureReason: Sendable, Equatable {
    case noConnection
    case verificationFailed
    case other

    // Sparkle's `SUSparkleErrorDomain` codes, copied here so LingvoCore does not import Sparkle.
    private static let sparkleDomain = "SUSparkleErrorDomain"
    private static let sparkleSignatureCodes: Set<Int> = [3001, 3002]
    private static let offlineURLCodes: Set<Int> = [
        NSURLErrorNotConnectedToInternet, NSURLErrorTimedOut,
        NSURLErrorCannotFindHost, NSURLErrorNetworkConnectionLost,
    ]

    public init(error: any Error) {
        let nsError = error as NSError
        // Sparkle wraps the network error of a failed download; look through the wrapper.
        if let inner = nsError.userInfo[NSUnderlyingErrorKey] as? NSError,
           Self.isOffline(inner) {
            self = .noConnection
        } else if Self.isOffline(nsError) {
            self = .noConnection
        } else if nsError.domain == Self.sparkleDomain, Self.sparkleSignatureCodes.contains(nsError.code) {
            self = .verificationFailed
        } else {
            self = .other
        }
    }

    private static func isOffline(_ error: NSError) -> Bool {
        error.domain == NSURLErrorDomain && offlineURLCodes.contains(error.code)
    }
}

/// What happened to the update. The app turns each Sparkle callback and each click into one event.
public enum UpdateEvent: Sendable, Equatable {
    case foundVersion(String)
    case foundNothing
    case installClicked
    case progress(Double)
    case downloadVerified
    case failed(UpdateFailureReason)
}

/// What the tray header shows for the update button.
public struct UpdateButton: Sendable, Equatable {
    public enum Label: Sendable, Equatable {
        case version(String)
        case percent(Int)
        case restarting
        case retry
    }

    public let label: Label
    public let acceptsClicks: Bool
    /// The version the click installs, for the tooltip.
    public let version: String
}

/// The update flow as a pure state machine: events in, the next state and the UI values out.
public enum UpdateState: Sendable, Equatable {
    case idle
    case available(String)
    case downloading(version: String, fraction: Double)
    case restarting(version: String)
    case failed(version: String, reason: UpdateFailureReason)

    public func applying(_ event: UpdateEvent) -> UpdateState {
        switch event {
        case .foundVersion(let version): afterCheck(found: version)
        case .foundNothing: afterCheck(found: nil)
        case .installClicked: afterClick()
        case .progress(let fraction): afterProgress(fraction)
        case .downloadVerified: afterVerified()
        case .failed(let reason): afterFailure(reason)
        }
    }

    public var button: UpdateButton? {
        switch self {
        case .idle:
            nil
        case .available(let version):
            UpdateButton(label: .version(version), acceptsClicks: true, version: version)
        case .downloading(let version, let fraction):
            UpdateButton(label: .percent(Int((fraction * 100).rounded())), acceptsClicks: false, version: version)
        case .restarting(let version):
            UpdateButton(label: .restarting, acceptsClicks: false, version: version)
        case .failed(let version, _):
            UpdateButton(label: .retry, acceptsClicks: true, version: version)
        }
    }

    public var failureReason: UpdateFailureReason? {
        if case .failed(_, let reason) = self { reason } else { nil }
    }

    /// The menu-bar mark: the update waits for a click, or its last try failed.
    public var showsUpdateMark: Bool {
        switch self {
        case .available, .failed: true
        case .idle, .downloading, .restarting: false
        }
    }

    // A check (the scheduled one included) must not touch a running download or restart.
    private func afterCheck(found version: String?) -> UpdateState {
        switch self {
        case .downloading, .restarting: self
        case .idle, .available, .failed: version.map(UpdateState.available) ?? .idle
        }
    }

    private func afterClick() -> UpdateState {
        switch self {
        case .available(let version), .failed(let version, _): .downloading(version: version, fraction: 0)
        case .idle, .downloading, .restarting: self
        }
    }

    private func afterProgress(_ fraction: Double) -> UpdateState {
        guard case .downloading(let version, _) = self else { return self }
        return .downloading(version: version, fraction: min(max(fraction, 0), 1))
    }

    private func afterVerified() -> UpdateState {
        guard case .downloading(let version, _) = self else { return self }
        return .restarting(version: version)
    }

    private func afterFailure(_ reason: UpdateFailureReason) -> UpdateState {
        switch self {
        case .idle: self
        case .available(let version), .downloading(let version, _), .restarting(let version),
             .failed(let version, _):
            .failed(version: version, reason: reason)
        }
    }
}
