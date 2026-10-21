import Foundation
import LingvoCore

/// Reads the macOS signals at the moment a card is requested and packs them
/// into the plain value the tutor needs.
@MainActor
struct CardContextBuilder {
    /// Read at every tick, so a change in Settings applies to the next one.
    let settings: SettingsModel
    /// `--quiet-hours` (QA) wins over the stored quiet hours for this run.
    let quietHoursOverride: QuietHoursOverride?
    let focus: any FocusStatusReading
    let fullScreen: any FullScreenDetecting
    let pause: PauseStore

    func context(for trigger: CardContext.Trigger) -> CardContext {
        // An on-demand card ignores the signals, so do not query the system for them.
        guard trigger == .timer else { return CardContext(trigger: .onDemand) }
        var context = CardContext.timer(
            settings: settings.settings,
            isFocusOn: focus.isFocusOn,
            isFullScreenAppFrontmost: fullScreen.isOtherAppFullScreen(),
            pausedUntil: pause.pausedUntil(),
            calendar: .current
        )
        switch quietHoursOverride {
        case nil: break
        case .off: context.quietHours = nil
        case .hours(let hours): context.quietHours = hours
        }
        return context
    }
}
