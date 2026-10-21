import LingvoCore
import SwiftUI

/// One view state that `--snapshot` renders to `<name>.png`.
/// Names follow the design screenshots (`design/screenshots/<name>.png`) where one exists.
struct SnapshotState {
    let name: String
    let view: @MainActor () -> AnyView
}

/// Every UI slice registers its designed states here.
@MainActor
enum SnapshotRegistry {
    static var all: [SnapshotState] {
        QuizCardSnapshots.states
    }
}

@MainActor
enum QuizCardSnapshots {
    static var states: [SnapshotState] {
        [
            state("q0_new_unanswered", DesignSamples.although, answer: nil),
            state("q1_new_correct", DesignSamples.although, answer: DesignSamples.althoughCorrect),
            state("q2_new_wrong", DesignSamples.although, answer: DesignSamples.althoughWrong),
            state("q3_new_dunno", DesignSamples.although, answer: DesignSamples.althoughDontKnow),
            state("q4_review_unanswered", DesignSamples.enoughReview, answer: nil),
            state("q5_review_correct_learned", DesignSamples.enoughReview, answer: DesignSamples.enoughReviewPassed),
        ]
    }

    private static func state(_ name: String, _ card: Card, answer: QuizCardState.Answer?) -> SnapshotState {
        SnapshotState(name: name) {
            AnyView(QuizCardView(state: QuizCardState(card: card, answer: answer)))
        }
    }
}
