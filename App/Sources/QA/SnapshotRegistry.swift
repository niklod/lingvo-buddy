#if DEBUG
import LingvoCore
import SwiftUI

/// One view state that `--snapshot` renders to `<name>.png`.
/// Names follow the design screenshots (`design/screenshots/<name>.png`) where one exists.
struct SnapshotState {
    let name: String
    /// Render in an offscreen window: needed for AppKit-backed controls.
    var usesWindow = false
    /// Shown in a `FloatingPanel`: `--check-panel-sizes` measures it as the panel does.
    var isPanel = false
    /// Async so a state can wait for work the view starts (the fake machine translator).
    let view: @MainActor () async -> AnyView
}

/// Every UI slice registers its designed states here.
@MainActor
enum SnapshotRegistry {
    static var all: [SnapshotState] {
        QuizCardSnapshots.states + StatusIconSnapshots.states + TrayMenuSnapshots.states
            + SettingsSnapshots.states + QuickAddSnapshots.states + OnboardingSnapshots.states + DictionarySnapshots.states
            + SystemDictionarySnapshots.states + ChainedLookupSnapshots.states
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
            state("q6_mine_unanswered", DesignSamples.suggestMine, answer: nil),
            state("q7_mine_wrong", DesignSamples.suggestMine, answer: DesignSamples.suggestMineWrong),
            state("q8_top2000_word", DesignSamples.eventuallyTop2000, answer: nil),
            state("q9_long_options", DesignSamples.mediaLongOptions, answer: nil),
            state("q10_russian_example_unanswered", DesignSamples.althoughWithRussianExample, answer: nil),
            state(
                "q11_russian_example_correct",
                DesignSamples.althoughWithRussianExample,
                answer: DesignSamples.althoughCorrect,
                showsExampleTranslation: true
            ),
            state("q12_russian_example_hidden", DesignSamples.althoughWithRussianExample, answer: DesignSamples.althoughCorrect),
            state("q13_mine_saved_ipa_pos", DesignSamples.petrichorMine, answer: nil),
            state("q8_new_correct_too_soon", DesignSamples.requirePractice, answer: DesignSamples.requireTooSoon),
            state("q9_new_unanswered_practice", DesignSamples.requirePractice, answer: nil),
            state("q14_correct_too_soon_hours", DesignSamples.requirePractice, answer: DesignSamples.requireTooSoonLong),
        ]
    }

    private static func state(
        _ name: String,
        _ card: Card,
        answer: QuizCardState.Answer?,
        showsExampleTranslation: Bool = false
    ) -> SnapshotState {
        SnapshotState(name: name, isPanel: true) {
            AnyView(QuizCardView(state: QuizCardState(
                card: card,
                answer: answer,
                showsExampleTranslation: showsExampleTranslation
            )))
        }
    }
}

/// The menu-bar icon as macOS tints it on a dark menu bar, scaled up so the marks are easy to check.
@MainActor
enum StatusIconSnapshots {
    private static let zoom: CGFloat = 4
    /// A dark menu bar behind the icon, as macOS draws it.
    private static let menuBar = Theme.Palette.menuBar

    static var states: [SnapshotState] {
        StatusMarks.all.map(state)
    }

    private static func state(_ marks: StatusMarks) -> SnapshotState {
        let name = "menubar_icon" + (marks.waiting ? "_waiting" : "") + (marks.updateMark ? "_update" : "")
        return SnapshotState(name: name) {
            let image = StatusGlyph.image(marks)
            return AnyView(
                Image(nsImage: image)
                    .renderingMode(.template)
                    .resizable()
                    .foregroundStyle(.white)
                    .frame(width: image.size.width * zoom, height: image.size.height * zoom)
                    .padding(8 * zoom)
                    .background(Self.menuBar)
            )
        }
    }
}
#endif
