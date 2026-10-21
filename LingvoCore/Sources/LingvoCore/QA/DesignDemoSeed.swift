import Foundation
import GRDB

/// QA hook: puts the user database into the state shown by the design sample
/// data, so screenshots of the running app can be compared with the design.
public enum DesignDemoSeed {
    private struct Sample {
        let headword: String
        let mastery: Int
        let lastResult: AnswerOutcome
        let minutesAgo: Double
    }

    private struct MySample {
        let headword: String
        let translation: String
        let example: String?
        /// `nil`: added, not answered yet.
        let wrongMinutesAgo: Double?
    }

    /// The "mine" rows of the design's Dictionary window; `suggest` is the q6/q7 card.
    private static let myWords: [MySample] = [
        MySample(headword: "suggest", translation: "предлагать",
                 example: "I suggest we start again tomorrow.", wrongMinutesAgo: 60 * 24),
        MySample(headword: "reluctant", translation: "неохотный",
                 example: "He was reluctant to admit the mistake.", wrongMinutesAgo: nil),
        MySample(headword: "eventually", translation: "в конце концов", example: nil, wrongMinutesAgo: 90),
    ]

    /// The Dictionary window rows of the design.
    private static let samples: [Sample] = [
        Sample(headword: "although", mastery: 2, lastResult: .correct, minutesAgo: 12),
        Sample(headword: "enough", mastery: 3, lastResult: .correct, minutesAgo: 60),
        Sample(headword: "provide", mastery: 1, lastResult: .correct, minutesAgo: 180),
        Sample(headword: "whether", mastery: 1, lastResult: .wrong, minutesAgo: 120),
        Sample(headword: "however", mastery: 3, lastResult: .correct, minutesAgo: 60 * 24),
        Sample(headword: "likely", mastery: 2, lastResult: .correct, minutesAgo: 40),
        Sample(headword: "require", mastery: 1, lastResult: .correct, minutesAgo: 300),
    ]

    /// Earlier days with answers, so the tray menu shows the design's 6-day streak.
    private static let historyDaysAgo = [2, 3, 4, 5]

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
                    kind: .new,
                    result: sample.lastResult,
                    answeredAt: answeredAt
                ),
                updating: progress(for: sample, answeredAt: answeredAt)
            )
        }
        try writeHistory(to: database, now: now)
        try writeMyWords(to: database, dictionary: dictionary, now: now)
    }

    private static func writeMyWords(to database: UserDatabase, dictionary: DictionaryStore, now: Date) throws {
        for (index, sample) in myWords.enumerated() {
            guard try dictionary.entry(headword: sample.headword) != nil else {
                throw LingvoCoreError.unknownWord(sample.headword)
            }
            let addedAt = now.addingTimeInterval(-Double(myWords.count - index) * 2 * 24 * 60 * 60)
            try database.insert(MyWord(
                headword: sample.headword,
                translation: sample.translation,
                example: sample.example,
                addedAt: addedAt
            ))
            guard let minutesAgo = sample.wrongMinutesAgo else { continue }
            let answeredAt = now.addingTimeInterval(-minutesAgo * 60)
            try database.record(
                AnswerRecord(headword: sample.headword, direction: .enToRu, kind: .mine, result: .wrong, answeredAt: answeredAt),
                updating: WordProgress(
                    headword: sample.headword, status: .learning, mastery: 0,
                    lastResult: .wrong, lastAnsweredAt: answeredAt, dueAt: answeredAt
                )
            )
        }
    }

    /// Log rows only: the stats read the answers log, the word rows stay as the design shows them.
    private static func writeHistory(to database: UserDatabase, now: Date) throws {
        try database.writer.write { db in
            for daysAgo in historyDaysAgo {
                try AnswerRecord(
                    headword: samples[0].headword,
                    direction: .enToRu,
                    kind: .new,
                    result: .correct,
                    answeredAt: now.addingTimeInterval(-Double(daysAgo) * 24 * 60 * 60)
                ).insert(db)
            }
        }
    }

    /// Design rows show mastery that the rules did not produce (a wrong last
    /// answer with dots), so the state is written as is, not replayed.
    private static func progress(for sample: Sample, answeredAt: Date) -> WordProgress {
        let correct = sample.lastResult == .correct
        return WordProgress(
            headword: sample.headword,
            status: .learning,
            mastery: sample.mastery,
            lastResult: sample.lastResult,
            lastAnsweredAt: answeredAt,
            enToRuCorrect: sample.mastery > 0,
            lastCountedCorrectAt: correct ? answeredAt : nil,
            dueAt: correct ? answeredAt.addingTimeInterval(WordProgress.countedCorrectGap) : answeredAt
        )
    }
}
