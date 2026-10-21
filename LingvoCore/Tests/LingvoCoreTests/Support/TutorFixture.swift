import Foundation
import LingvoCore
import Testing

enum Fixture {
    static let start = Date(timeIntervalSince1970: 1_792_000_000)
    static let minute: TimeInterval = 60
    static let hour: TimeInterval = 60 * minute
    static let day: TimeInterval = 24 * hour

    static func sampleDictionaryData() throws -> Data {
        let url = try #require(
            Bundle.module.url(forResource: "sample-dictionary", withExtension: "json", subdirectory: "Fixtures")
        )
        return try Data(contentsOf: url)
    }

    static func dictionary() throws -> DictionaryStore {
        try DictionaryStore.inMemory(fromJSON: [sampleDictionaryData()])
    }

    static func tutor(
        userDatabase: UserDatabase? = nil,
        dictionary: DictionaryStore? = nil,
        clock: TestClock = TestClock(start),
        seed: UInt64 = 1,
        settings: LearningSettings = LearningSettings()
    ) throws -> Tutor {
        Tutor(
            dictionary: try dictionary ?? Self.dictionary(),
            userDatabase: try userDatabase ?? UserDatabase.inMemory(),
            clock: clock,
            random: SeededRandomSource(seed: seed),
            settings: settings
        )
    }

    static func temporaryDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("lingvo-tests-\(UUID().uuidString)")
            .appendingPathExtension("sqlite")
    }
}
