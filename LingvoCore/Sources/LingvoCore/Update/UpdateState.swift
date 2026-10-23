import Foundation

/// Why an update failed. The tray shows one short line per reason.
public enum UpdateFailureReason: Sendable, Equatable {
    case noConnection
    case verificationFailed
    case other

    // Copied from Sparkle 2.10.0 `SUErrors.h`, so LingvoCore does not import Sparkle:
    // `SUSparkleErrorDomain`, `SUSignatureError` = 3001 and `SUValidationError` = 3002.
    private static let sparkleDomain = "SUSparkleErrorDomain"
    private static let sparkleSignatureCodes: Set<Int> = [3001, 3002]
    private static let offlineURLCodes: Set<Int> = [
        NSURLErrorNotConnectedToInternet, NSURLErrorTimedOut,
        NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost, NSURLErrorNetworkConnectionLost,
    ]

    /// Sparkle nests the cause: a download wraps the URL error, and a refused signature sits two
    /// levels under an installation error (4005). A real tree is 3 levels deep; the limit stops a cycle.
    private static let maxErrorDepth = 6

    public init(error: any Error) {
        let errors = Self.flatten(error as NSError, depth: Self.maxErrorDepth)
        if errors.contains(where: Self.isOffline) {
            self = .noConnection
        } else if errors.contains(where: Self.isSignatureError) {
            self = .verificationFailed
        } else {
            self = .other
        }
    }

    private static func flatten(_ error: NSError, depth: Int) -> [NSError] {
        guard depth > 0 else { return [error] }
        var children = (error.userInfo[NSMultipleUnderlyingErrorsKey] as? [NSError]) ?? []
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            children.append(underlying)
        }
        return [error] + children.flatMap { flatten($0, depth: depth - 1) }
    }

    private static func isOffline(_ error: NSError) -> Bool {
        error.domain == NSURLErrorDomain && offlineURLCodes.contains(error.code)
    }

    private static func isSignatureError(_ error: NSError) -> Bool {
        error.domain == sparkleDomain && sparkleSignatureCodes.contains(error.code)
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

public struct UpdateButton: Sendable, Equatable {
    public enum Label: Sendable, Equatable {
        /// The button shows `version`.
        case version
        case percent(Int)
        case restarting
        case retry
    }

    public let label: Label
    /// The version the click installs: the label of an offered update, and the tooltip.
    public let version: String

    public init(label: Label, version: String) {
        self.label = label
        self.version = version
    }

    /// A running download or restart must not start a second one.
    public var acceptsClicks: Bool {
        switch label {
        case .version, .retry: true
        case .percent, .restarting: false
        }
    }
}

/// The update flow as a pure state machine: events in, the next state and the UI values out.
public enum UpdateState: Sendable, Equatable {
    case idle
    case available(version: String)
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
            UpdateButton(label: .version, version: version)
        case .downloading(let version, let fraction):
            UpdateButton(label: .percent(Int((fraction * 100).rounded())), version: version)
        case .restarting(let version):
            UpdateButton(label: .restarting, version: version)
        case .failed(let version, _):
            UpdateButton(label: .retry, version: version)
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

    // Sparkle runs one session at a time, so a check during a download is the one the click
    // started: what it finds is what downloads, and "nothing found" means the update is gone.
    private func afterCheck(found version: String?) -> UpdateState {
        switch (self, version) {
        case (.restarting, _): self
        case (.downloading(_, let fraction), .some(let found)): .downloading(version: found, fraction: fraction)
        case (.downloading, nil): .idle
        case (.idle, _), (.available, _), (.failed, _): version.map { .available(version: $0) } ?? .idle
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
        // NaN passes min and max unchanged, and the button's Int(percent) would trap on it.
        let known = fraction.isNaN ? 0 : fraction
        return .downloading(version: version, fraction: min(max(known, 0), 1))
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
