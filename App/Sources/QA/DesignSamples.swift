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
        result: AnswerResult(outcome: .correct, correctIndex: 0, correctAnswer: "хотя", becameLearned: false, mastery: 3)
    )

    static let althoughWrong = QuizCardState.Answer(
        pickedIndex: 2,
        result: AnswerResult(outcome: .wrong, correctIndex: 0, correctAnswer: "хотя", becameLearned: false, mastery: 0)
    )
}
