#if DEBUG
import LingvoCore
import SwiftUI

/// One view state that `--snapshot` renders to `<name>.png`.
/// Names follow the design screenshots (`design/screenshots/<name>.png`) where one exists.
struct SnapshotState {
    let name: String
    /// Render in an offscreen window: needed for AppKit-backed controls.
    var usesWindow = false
    let view: @MainActor () -> AnyView
}

/// Every UI slice registers its designed states here.
@MainActor
enum SnapshotRegistry {
    static var all: [SnapshotState] {
        QuizCardSnapshots.states + StatusIconSnapshots.states + TrayMenuSnapshots.states
            + SettingsSnapshots.states + QuickAddSnapshots.states + OnboardingSnapshots.states + DictionarySnapshots.states
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
            state("q8_top2000_lookup_word", DesignSamples.eventuallyTop2000, answer: nil),
        ]
    }

    private static func state(_ name: String, _ card: Card, answer: QuizCardState.Answer?) -> SnapshotState {
        SnapshotState(name: name) {
            AnyView(QuizCardView(state: QuizCardState(card: card, answer: answer)))
        }
    }
}

/// The menu-bar icon as macOS tints it on a dark menu bar, scaled up so the dot is easy to check.
@MainActor
enum StatusIconSnapshots {
    private static let zoom: CGFloat = 4
    /// A dark menu bar behind the icon, as macOS draws it.
    private static let menuBar = Color(hex: 0x2B2B2E)

    static var states: [SnapshotState] {
        [state("menubar_icon", waiting: false), state("menubar_icon_waiting", waiting: true)]
    }

    private static func state(_ name: String, waiting: Bool) -> SnapshotState {
        SnapshotState(name: name) {
            let image = StatusGlyph.image(waiting: waiting)
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
