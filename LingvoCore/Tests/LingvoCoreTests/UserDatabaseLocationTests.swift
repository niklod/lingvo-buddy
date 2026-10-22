import Foundation
import LingvoCore
import Testing

/// `--user-db <name|path>` in a sandboxed app: only files inside the container work.
@Suite("User database location")
final class UserDatabaseLocationTests {
    let root: URL
    let container: URL
    let supportFolder: URL

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    init() throws {
        // realpath: the temporary folder itself sits behind the /var -> /private/var symlink.
        let temporary = URL(fileURLWithPath: FileManager.default.temporaryDirectory.path).resolvingSymlinksInPath()
        root = temporary.appendingPathComponent("user-db-location-\(UUID().uuidString)", isDirectory: true)
        container = root.appendingPathComponent("Container/Data", isDirectory: true)
        supportFolder = container.appendingPathComponent("Library/Application Support/LingvoBuddy", isDirectory: true)
        try FileManager.default.createDirectory(at: supportFolder, withIntermediateDirectories: true)
    }

    func resolve(_ value: String, sandboxed: Bool = true) throws -> URL {
        try UserDatabaseLocation.resolve(value, supportFolder: supportFolder, container: sandboxed ? container : nil)
    }

    @Test("a name resolves to a file in the app's support folder")
    func nameResolvesInsideTheSupportFolder() throws {
        #expect(try resolve("demo") == supportFolder.appendingPathComponent("demo.sqlite"))
    }

    @Test("a path inside the container is used as it is")
    func pathInsideTheContainerIsAccepted() throws {
        let path = container.appendingPathComponent("tmp/qa.sqlite").path

        #expect(try resolve(path).path == path)
    }

    @Test("a path outside the container fails and names the form that works")
    func pathOutsideTheContainerFails() throws {
        let error = #expect(throws: UserDatabaseLocationError.self) { try resolve("/tmp/x.sqlite") }

        #expect(error == .outsideContainer(path: "/tmp/x.sqlite", container: container.path))
        let message = try #require(error?.errorDescription)
        #expect(message.contains("--user-db /tmp/x.sqlite"))
        #expect(message.contains("--user-db <name>"))
        #expect(message.contains(container.path))
    }

    @Test("dot-dot and symlinks cannot lead out of the container")
    func escapesThroughDotDotOrSymlinksFail() throws {
        let outside = root.appendingPathComponent("Outside", isDirectory: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        let link = container.appendingPathComponent("Desktop")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)

        #expect(throws: UserDatabaseLocationError.self) { try resolve(container.path + "/../x.sqlite") }
        #expect(throws: UserDatabaseLocationError.self) { try resolve(link.path + "/x.sqlite") }
    }

    @Test("without a sandbox every path is allowed")
    func withoutASandboxAnyPathIsAccepted() throws {
        #expect(try resolve("/tmp/x.sqlite", sandboxed: false).path == "/tmp/x.sqlite")
    }
}
