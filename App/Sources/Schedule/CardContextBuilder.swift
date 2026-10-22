import Foundation
import LingvoCore

/// Reads the macOS signals at the moment a card is requested and packs them
/// into the plain value the tutor needs.
@MainActor
struct CardContextBuilder {
    /// Read at every tick, so a change in Settings applies to the next one.
    let settings: SettingsModel
    let quietHoursOverride: QuietHoursOverride?
    let focus: any FocusStatusReading
    let fullScreen: any FullScreenDetecting
    let pause: PauseStore

    /// Quiet hours are wall-clock times: the learner's zone can change while the app runs.
    private var calendar: Calendar { .autoupdatingCurrent }

    func context(for trigger: CardContext.Trigger, at now: Date) -> CardContext {
        // An on-demand card ignores the signals, so do not query the system for them.
        guard trigger == .timer else { return CardContext(trigger: .onDemand) }
        let pausedUntil = pause.pausedUntil(now: now)
        let quietHours = quietHours
        // A pause or quiet hours hold the card anyway. Then the Focus and
        // window-server queries would only cost energy, every minute, all night.
        let isHeld = pausedUntil != nil || quietHours?.contains(now, calendar: calendar) == true
        let isFocusOn = !isHeld && focus.isFocusOn
        // Focus outranks full screen in the core rules, so its answer is enough.
        let isFullScreen = !isHeld && !isFocusOn && fullScreen.isOtherAppFullScreen()
        return CardContext(
            trigger: .timer,
            quietHours: quietHours,
            isFocusOn: isFocusOn,
            isFullScreenAppFrontmost: isFullScreen,
            pausedUntil: pausedUntil,
            calendar: calendar
        )
    }

    /// When the quiet span that holds cards at `now` ends, for the tray label.
    func quietHoursEnd(after now: Date) -> Date? {
        guard let end = quietHours?.end else { return nil }
        return calendar.nextDate(
            after: now,
            matching: DateComponents(hour: end.hour, minute: end.minute),
            matchingPolicy: .nextTime
        )
    }

    /// `--quiet-hours` (QA) wins over the stored quiet hours for this run.
    private var quietHours: QuietHours? {
        switch quietHoursOverride {
        case nil: settings.settings.activeQuietHours
        case .off: nil
        case .hours(let hours): hours
        }
    }
}
