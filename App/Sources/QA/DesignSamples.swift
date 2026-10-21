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

    /// Answers on the `although` card, which stays in learning.
    private static func result(_ outcome: AnswerOutcome, correctAnswer: String, mastery: Int) -> AnswerResult {
        AnswerResult(
            outcome: outcome, correctIndex: 0, correctAnswer: correctAnswer,
            becameLearned: false, isLearned: false, mastery: mastery
        )
    }
}
