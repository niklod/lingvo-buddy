import Foundation

/// QA hooks passed as launch arguments (`make run ARGS="…"`, `make snapshots`).
struct LaunchOptions: Equatable {
    /// `--user-db <name|path>`: a name resolves to `<Application Support>/LingvoBuddy/<name>.sqlite`.
    var userDatabase: String?
    /// `--seed-demo`: replace the user state with the design sample state.
    var seedDemo = false
    /// `--snapshot <dir>`: render all registered views to PNG, then exit.
    /// A relative dir resolves inside the app's temporary folder (sandbox container).
    var snapshotDirectory: String?
    /// `--snapshot-filter <text>`: render only states whose name contains the text.
    var snapshotFilter: String?
    /// `--open <view>`: open a view right after launch.
    var openView: OpenableView?

    static func parse(_ arguments: [String]) throws -> LaunchOptions {
        var options = LaunchOptions()
        var remaining = arguments.dropFirst()[...]
        while let argument = remaining.popFirst() {
            switch argument {
            case "--user-db": options.userDatabase = try value(for: argument, from: &remaining)
            case "--seed-demo": options.seedDemo = true
            case "--snapshot": options.snapshotDirectory = try value(for: argument, from: &remaining)
            case "--snapshot-filter": options.snapshotFilter = try value(for: argument, from: &remaining)
            case "--open":
                let name = try value(for: argument, from: &remaining)
                guard let view = OpenableView(rawValue: name) else {
                    throw LaunchOptionsError.unknownView(name)
                }
                options.openView = view
            default:
                // Xcode and LaunchServices add their own arguments (-NSDocumentRevisionsDebugMode, -psn_…).
                continue
            }
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

/// Views that `--open` can show immediately. Later slices add their views here.
enum OpenableView: String, CaseIterable {
    case card
}

enum LaunchOptionsError: Error, LocalizedError {
    case missingValue(String)
    case unknownView(String)

    var errorDescription: String? {
        switch self {
        case .missingValue(let flag):
            "\(flag) needs a value."
        case .unknownView(let name):
            "Unknown view \"\(name)\" for --open. Known: \(OpenableView.allCases.map(\.rawValue).joined(separator: ", "))."
        }
    }
}
