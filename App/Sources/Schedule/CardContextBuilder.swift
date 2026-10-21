import Foundation
import LingvoCore

/// Reads the macOS signals at the moment a card is requested and packs them
/// into the plain value the tutor needs.
@MainActor
struct CardContextBuilder {
    let quietHours: QuietHours?
    let focus: any FocusStatusReading
    let fullScreen: any FullScreenDetecting
    let pause: PauseStore

    func context(for trigger: CardContext.Trigger) -> CardContext {
        // An on-demand card ignores the signals, so do not query the system for them.
        guard trigger == .timer else { return CardContext(trigger: .onDemand) }
        return CardContext(
            trigger: .timer,
            quietHours: quietHours,
            isFocusOn: focus.isFocusOn,
            isFullScreenAppFrontmost: fullScreen.isOtherAppFullScreen(),
            pausedUntil: pause.pausedUntil(),
            calendar: .current
        )
    }
}
