import Foundation

/// QA hook: puts the user database into the state shown by the design sample
/// data, so screenshots of the running app can be compared with the design.
public enum DesignDemoSeed {
    private struct Sample {
        let headword: String
        let mastery: Int
        let lastResult: AnswerOutcome
        let minutesAgo: Double
    }

    /// The Dictionary window rows of the design ("My words" rows arrive with quick add).
    private static let samples: [Sample] = [
        Sample(headword: "although", mastery: 2, lastResult: .correct, minutesAgo: 12),
        Sample(headword: "enough", mastery: 3, lastResult: .correct, minutesAgo: 60),
        Sample(headword: "provide", mastery: 1, lastResult: .correct, minutesAgo: 180),
        Sample(headword: "whether", mastery: 1, lastResult: .wrong, minutesAgo: 120),
        Sample(headword: "however", mastery: 3, lastResult: .correct, minutesAgo: 60 * 24),
        Sample(headword: "likely", mastery: 2, lastResult: .correct, minutesAgo: 40),
        Sample(headword: "require", mastery: 1, lastResult: .correct, minutesAgo: 300),
    ]

    /// Erases the learner state, then writes the design sample state relative to `now`.
    public static func apply(to database: UserDatabase, dictionary: DictionaryStore, now: Date) throws {
        try database.eraseAll()
        for sample in samples {
            guard try dictionary.entry(headword: sample.headword) != nil else {
                throw LingvoCoreError.unknownWord(sample.headword)
            }
            let answeredAt = now.addingTimeInterval(-sample.minutesAgo * 60)
            try database.record(
                AnswerRecord(
                    headword: sample.headword,
                    direction: .enToRu,
                    result: sample.lastResult,
                    answeredAt: answeredAt
                ),
                updating: WordProgress(
                    headword: sample.headword,
                    status: .learning,
                    mastery: sample.mastery,
                    lastResult: sample.lastResult,
                    lastAnsweredAt: answeredAt
                )
            )
        }
    }
}
