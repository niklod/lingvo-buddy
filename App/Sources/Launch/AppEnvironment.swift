import Foundation
import LingvoCore

/// Builds the tutor from the bundled dictionary and the user database on disk.
enum AppEnvironment {
    static let defaultUserDatabaseName = "user"

    enum SetupError: Error, LocalizedError {
        case missingBundledDictionary

        var errorDescription: String? {
            "The bundled dictionary is missing. Run `make dictionary` and rebuild the app."
        }
    }

    static func makeTutor(options: LaunchOptions) throws -> Tutor {
        let dictionary = try bundledDictionary()
        let userDatabase = try UserDatabase.open(at: userDatabaseURL(options.userDatabase))
        if options.seedDemo {
            try DesignDemoSeed.apply(to: userDatabase, dictionary: dictionary, now: Date())
        }
        return Tutor(dictionary: dictionary, userDatabase: userDatabase)
    }

    /// The QA override wins over the interval the learner chose.
    @MainActor
    static func scheduleSettings(options: LaunchOptions, stored: IntervalStore) throws -> CardScheduleSettings {
        guard let interval = options.cardInterval else { return stored.settings() }
        return try CardScheduleSettings(interval: interval)
    }

    static func quietHours(options: LaunchOptions) -> QuietHours? {
        switch options.quietHours {
        case nil: .standard
        case .off: nil
        case .hours(let hours): hours
        }
    }

    private static func bundledDictionary() throws -> DictionaryStore {
        guard let url = Bundle.main.url(forResource: "dictionary", withExtension: "sqlite") else {
            throw SetupError.missingBundledDictionary
        }
        return try DictionaryStore.open(at: url)
    }

    static func userDatabaseURL(_ nameOrPath: String?) throws -> URL {
        let value = nameOrPath ?? defaultUserDatabaseName
        if value.contains("/") {
            return URL(fileURLWithPath: value)
        }
        return try applicationSupportFolder().appendingPathComponent(value).appendingPathExtension("sqlite")
    }

    private static func applicationSupportFolder() throws -> URL {
        try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("LingvoBuddy", isDirectory: true)
    }
}
