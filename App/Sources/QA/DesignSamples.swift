#if DEBUG
import LingvoCore

/// The sample cards from the design file, as fixed values for snapshots.
enum DesignSamples {
    static let although = Card(
        headword: "although",
        prompt: "although",
        direction: .enToRu,
        kind: .new,
        source: .rank(312),
        ipa: "/ɔːlˈðəʊ/",
        partOfSpeech: .conjunction,
        options: ["хотя", "поэтому", "кроме того", "вдруг"],
        correctIndex: 0,
        example: "Although it was late, we kept working.",
        mastery: 2
    )

    static let althoughCorrect = QuizCardState.Answer(
        pickedIndex: 0,
        result: result(.correct, correctAnswer: "хотя", mastery: 3)
    )

    static let althoughWrong = QuizCardState.Answer(
        pickedIndex: 2,
        result: result(.wrong, correctAnswer: "хотя", mastery: 0)
    )

    static let althoughDontKnow = QuizCardState.Answer(
        pickedIndex: nil,
        result: result(.dontKnow, correctAnswer: "хотя", mastery: 0)
    )

    /// A learned word due for review, asked RU → EN.
    static let enoughReview = Card(
        headword: "enough",
        prompt: "достаточно",
        direction: .ruToEn,
        kind: .review,
        source: .rank(188),
        ipa: "/ɪˈnʌf/",
        partOfSpeech: .adverb,
        options: ["too", "enough", "barely", "almost"],
        correctIndex: 1,
        example: "Is there enough coffee for everyone?",
        mastery: 4
    )

    static let enoughReviewPassed = QuizCardState.Answer(
        pickedIndex: 1,
        result: AnswerResult(
            outcome: .correct, correctIndex: 1, correctAnswer: "enough",
            becameLearned: false, isLearned: true, mastery: 4
        )
    )

    /// A Top‑2000 card for a lookup-tier word: it has no example sentence.
    static let eventuallyTop2000 = Card(
        headword: "eventually",
        prompt: "eventually",
        direction: .enToRu,
        kind: .new,
        source: .rank(1308),
        ipa: "/ɪˈventʃuəli/",
        partOfSpeech: .adverb,
        options: ["немедленно", "в конце концов", "почти", "очевидно"],
        correctIndex: 1,
        example: nil,
        mastery: 0
    )

    /// The longest main translations of the bundled card words: no option may be cut off.
    static let mediaLongOptions = Card(
        headword: "media",
        prompt: "media",
        direction: .enToRu,
        kind: .new,
        source: .rank(516),
        ipa: "/ˈmiːdiə/",
        partOfSpeech: .noun,
        options: ["средства массовой информации", "статистический показатель", "программное обеспечение", "вдруг"],
        correctIndex: 0,
        example: "The story was in all the media today.",
        mastery: 0
    )

    /// A word the learner added with quick add, before its first counted answer.
    static let suggestMine = Card(
        headword: "suggest",
        prompt: "suggest",
        direction: .enToRu,
        kind: .mine,
        source: .mine,
        ipa: "/səˈdʒest/",
        partOfSpeech: .verb,
        options: ["требовать", "отказывать", "предлагать", "объяснять"],
        correctIndex: 2,
        example: "I suggest we start again tomorrow.",
        mastery: 0
    )

    static let suggestMineWrong = QuizCardState.Answer(
        pickedIndex: 0,
        result: AnswerResult(
            outcome: .wrong, correctIndex: 2, correctAnswer: "предлагать",
            becameLearned: false, isLearned: false, mastery: 0
        )
    )

    /// Answers on the `although` card, which stays in learning.
    private static func result(_ outcome: AnswerOutcome, correctAnswer: String, mastery: Int) -> AnswerResult {
        AnswerResult(
            outcome: outcome, correctIndex: 0, correctAnswer: correctAnswer,
            becameLearned: false, isLearned: false, mastery: mastery
        )
    }
}
#endif
