import Foundation
import LingvoCore

/// Builds the tutor from the bundled dictionary and the user database on disk.
enum AppEnvironment {
    static let defaultUserDatabaseName = "user"

    enum SetupError: Error, LocalizedError {
        case missingBundledDictionary
        case missingExtendedDictionary
        case seedDemoOnLearnerDatabase

        var errorDescription: String? {
            switch self {
            case .missingBundledDictionary:
                "The bundled dictionary is missing. Run `make dictionary` and rebuild the app."
            case .missingExtendedDictionary:
                "The extended dictionary is missing. Run `make dictionary` and rebuild the app."
            case .seedDemoOnLearnerDatabase:
                "--seed-demo would replace the learner's own database. Pass --user-db with a test database."
            }
        }
    }

    struct Services {
        let tutor: Tutor
        /// The bundled dictionary's `meta` table (source, licence) for About.
        let dictionaryMeta: [String: String]
        /// The extended dictionary's `meta` table: the Wiktionary licence note for About.
        let extendedMeta: [String: String]
    }

    static func makeServices(options: LaunchOptions) throws -> Services {
        let dictionary = try bundledDictionary()
        let extended = try extendedDictionary()
        let userDatabaseURL = try userDatabaseURL(options.userDatabase)
        // A name check is not enough: `--user-db` with the full path names the same file.
        if options.seedDemo, try userDatabaseURL.standardizedFileURL == Self.userDatabaseURL(nil).standardizedFileURL {
            throw SetupError.seedDemoOnLearnerDatabase
        }
        let userDatabase = try UserDatabase.open(at: userDatabaseURL)
        if options.seedDemo {
            try DesignDemoSeed.apply(to: userDatabase, dictionary: dictionary, now: SystemClock().now())
        }
        return Services(
            tutor: try Tutor(dictionary: dictionary, userDatabase: userDatabase, extendedDictionary: extended),
            dictionaryMeta: try dictionary.meta(),
            extendedMeta: try extended.meta()
        )
    }

    /// The stored interval, or the `--interval-seconds` QA override for this run.
    static func scheduleSettings(options: LaunchOptions, settings: TutorSettings) throws -> CardScheduleSettings {
        try CardScheduleSettings(interval: options.cardInterval ?? settings.cardInterval)
    }

    private static func bundledDictionary() throws -> DictionaryStore {
        guard let url = Bundle.main.url(forResource: "dictionary", withExtension: "sqlite") else {
            throw SetupError.missingBundledDictionary
        }
        return try DictionaryStore.open(at: url)
    }

    private static func extendedDictionary() throws -> ExtendedDictionary {
        guard let url = Bundle.main.url(forResource: "extended-dictionary", withExtension: "sqlite") else {
            throw SetupError.missingExtendedDictionary
        }
        return try ExtendedDictionary.open(at: url)
    }

    static func userDatabaseURL(_ nameOrPath: String?) throws -> URL {
        try UserDatabaseLocation.resolve(
            nameOrPath ?? defaultUserDatabaseName,
            supportFolder: applicationSupportFolder(),
            container: sandboxContainer()
        )
    }

    /// In the sandbox the home folder is the container; the sandbox sets APP_SANDBOX_CONTAINER_ID.
    private static func sandboxContainer() -> URL? {
        guard ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil else { return nil }
        return URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
    }

    private static func applicationSupportFolder() throws -> URL {
        try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("LingvoBuddy", isDirectory: true)
    }
}
