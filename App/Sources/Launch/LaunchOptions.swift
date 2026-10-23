import Foundation
import LingvoCore

/// QA hooks passed as launch arguments (`make run ARGS="…"`, `make snapshots`).
/// Only Debug builds read them: in a shipped app any local process could
/// otherwise reseed or redirect the learner's data with `open --args`.
struct LaunchOptions: Equatable {
    /// `--user-db <name|path>`: a name resolves to `<Application Support>/LingvoBuddy/<name>.sqlite`.
    /// A path must be inside the sandbox container, or launch fails.
    var userDatabase: String?
    /// `--seed-demo`: replace the user state with the design sample state.
    /// Needs a `--user-db` other than the learner's own database.
    var seedDemo = false
    /// `--snapshot <dir>`: render all registered views to PNG, then exit.
    /// A relative dir resolves inside the app's temporary folder (sandbox container).
    var snapshotDirectory: String?
    /// `--snapshot-filter <text>`: render only states whose name contains the text.
    var snapshotFilter: String?
    /// `--check-panel-sizes`: measure every panel state as `FloatingPanel` does, then exit 1 if one is endless.
    var checksPanelSizes = false
    /// `--open <view>`: open a view right after launch.
    var openView: OpenableView?
    /// `--prefill <text>`: the word `--open quick-add` starts with.
    var prefill: String?
    /// `--interval-seconds <n>`: the card interval in seconds instead of the stored interval.
    var cardInterval: TimeInterval?
    /// `--quiet-hours <HH:MM-HH:MM|off>`: replaces the stored quiet hours for this run.
    var quietHours: QuietHoursOverride?
    /// `--skip-onboarding`: do not show first-run onboarding in this run (QA on fresh databases).
    var skipOnboarding = false
    /// `--update-state available|downloading|restarting|failed`: shows that update state with a fake version.
    var forcedUpdateState: ForcedUpdateState?

    static func parse(_ arguments: [String]) throws -> LaunchOptions {
        #if DEBUG
        try parseQAFlags(arguments)
        #else
        LaunchOptions()
        #endif
    }

    private static func parseQAFlags(_ arguments: [String]) throws -> LaunchOptions {
        var options = LaunchOptions()
        var remaining = arguments.dropFirst()[...]
        while let argument = remaining.popFirst() {
            switch argument {
            case "--user-db": options.userDatabase = try value(for: argument, from: &remaining)
            case "--seed-demo": options.seedDemo = true
            case "--skip-onboarding": options.skipOnboarding = true
            case "--snapshot": options.snapshotDirectory = try value(for: argument, from: &remaining)
            case "--snapshot-filter": options.snapshotFilter = try value(for: argument, from: &remaining)
            case "--check-panel-sizes": options.checksPanelSizes = true
            case "--open":
                let name = try value(for: argument, from: &remaining)
                guard let view = OpenableView(rawValue: name) else {
                    throw LaunchOptionsError.unknownView(name)
                }
                options.openView = view
            case "--prefill": options.prefill = try value(for: argument, from: &remaining)
            case "--interval-seconds":
                let text = try value(for: argument, from: &remaining)
                guard let seconds = TimeInterval(text), seconds > 0 else {
                    throw LaunchOptionsError.invalidValue(argument, text)
                }
                options.cardInterval = seconds
            case "--quiet-hours":
                let text = try value(for: argument, from: &remaining)
                options.quietHours = try QuietHoursOverride.parse(text, flag: argument)
            case "--update-state":
                let name = try value(for: argument, from: &remaining)
                guard let forced = ForcedUpdateState(rawValue: name) else {
                    throw LaunchOptionsError.invalidValue(argument, name)
                }
                options.forcedUpdateState = forced
            default:
                // Xcode and LaunchServices add their own arguments (-NSDocumentRevisionsDebugMode, -psn_…).
                continue
            }
        }
        guard !options.seedDemo || options.userDatabase != nil else {
            throw LaunchOptionsError.seedDemoNeedsUserDatabase
        }
        return options
    }

    private static func value(for flag: String, from remaining: inout ArraySlice<String>) throws -> String {
        guard let value = remaining.popFirst(), !value.hasPrefix("--") else {
            throw LaunchOptionsError.missingValue(flag)
        }
        return value
    }
}

/// Views that `--open` can show immediately.
enum OpenableView: String, CaseIterable {
    case card
    case tray
    case settings
    case about
    case quickAdd = "quick-add"
    /// Shows onboarding again, even when it is already done.
    case onboarding
    case dictionary
}

/// The value of `--update-state`.
enum ForcedUpdateState: String, CaseIterable {
    case available
    case downloading
    case restarting
    case failed

    /// A version no Release has, so a forced state never looks like a real update.
    static let fakeVersion = "9.9.9"

    var state: UpdateState {
        switch self {
        case .available: .available(Self.fakeVersion)
        case .downloading: .downloading(version: Self.fakeVersion, fraction: 0.42)
        case .restarting: .restarting(version: Self.fakeVersion)
        case .failed: .failed(version: Self.fakeVersion, reason: .noConnection)
        }
    }
}

/// The value of `--quiet-hours`.
enum QuietHoursOverride: Equatable {
    case off
    case hours(QuietHours)

    static func parse(_ text: String, flag: String) throws -> QuietHoursOverride {
        if text == "off" { return .off }
        let bounds = text.split(separator: "-").map(String.init)
        guard bounds.count == 2, let start = try? time(bounds[0]), let end = try? time(bounds[1]) else {
            throw LaunchOptionsError.invalidValue(flag, text)
        }
        return .hours(QuietHours(start: start, end: end))
    }

    private static func time(_ text: String) throws -> TimeOfDay {
        let parts = text.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { throw LaunchOptionsError.invalidValue("--quiet-hours", text) }
        return try TimeOfDay(hour: parts[0], minute: parts[1])
    }
}

enum LaunchOptionsError: Error, LocalizedError {
    case missingValue(String)
    case unknownView(String)
    case invalidValue(String, String)
    case seedDemoNeedsUserDatabase

    var errorDescription: String? {
        switch self {
        case .missingValue(let flag):
            "\(flag) needs a value."
        case .unknownView(let name):
            "Unknown view \"\(name)\" for --open. Known: \(OpenableView.allCases.map(\.rawValue).joined(separator: ", "))."
        case .invalidValue(let flag, let value):
            "\"\(value)\" is not a valid value for \(flag)."
        case .seedDemoNeedsUserDatabase:
            "--seed-demo replaces every word and answer, so it needs --user-db with a test database."
        }
    }
}
