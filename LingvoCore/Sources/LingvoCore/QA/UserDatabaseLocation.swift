import Foundation

/// QA hook `--user-db <name|path>`: the user database file for this run.
///
/// The sandbox lets the app write only inside its container. Outside it, SQLite gets a
/// file it cannot use (an empty file, then failed writes), so such a path fails at launch.
public enum UserDatabaseLocation {
    /// - Parameters:
    ///   - value: a name (no "/") or a path.
    ///   - supportFolder: where names resolve to `<name>.sqlite`.
    ///   - container: the sandbox container, or nil when the app runs without a sandbox.
    public static func resolve(_ value: String, supportFolder: URL, container: URL?) throws -> URL {
        guard value.contains("/") else {
            return supportFolder.appendingPathComponent(value).appendingPathExtension("sqlite")
        }
        let url = URL(fileURLWithPath: value).standardizedFileURL
        if let container, !isInside(url, container) {
            throw UserDatabaseLocationError.outsideContainer(path: value, container: container.path)
        }
        return url
    }

    private static func isInside(_ url: URL, _ folder: URL) -> Bool {
        let path = realPath(url).pathComponents
        let folderPath = realPath(folder).pathComponents
        return path.count > folderPath.count && Array(path.prefix(folderPath.count)) == folderPath
    }

    /// Resolves symlinks in the part of the path that exists: the database file itself may not exist yet,
    /// and a container folder such as Desktop can be a symlink to a folder outside the container.
    private static func realPath(_ url: URL) -> URL {
        var existing = url.standardizedFileURL
        var missing: [String] = []
        while existing.path != "/", !FileManager.default.fileExists(atPath: existing.path) {
            missing.insert(existing.lastPathComponent, at: 0)
            existing.deleteLastPathComponent()
        }
        guard let resolved = realpath(existing.path, nil) else { return url.standardizedFileURL }
        defer { free(resolved) }
        return missing.reduce(URL(fileURLWithPath: String(cString: resolved))) { $0.appendingPathComponent($1) }
    }
}

public enum UserDatabaseLocationError: Error, LocalizedError, Equatable, Sendable {
    case outsideContainer(path: String, container: String)

    public var errorDescription: String? {
        switch self {
        case .outsideContainer(let path, let container):
            "--user-db \(path) is outside the app's sandbox container (\(container)), so the app cannot use it. "
                + "Pass --user-db <name> for <name>.sqlite in the app's Application Support folder, "
                + "or a path inside the container."
        }
    }
}
