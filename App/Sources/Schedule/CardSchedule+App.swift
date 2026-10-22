import Foundation
import LingvoCore

/// Schedule steps the app needs that the core schedule has no event for yet.
/// Each is built from public events only, so the core rules still decide every field.
extension CardSchedule {
    /// The waiting card's word was deleted or changed: the dot must go, and the
    /// countdown must stay where it was. Showing then closing the card clears it;
    /// closing at `nextCardAt - interval` puts the countdown back on the same moment.
    func droppingWaitingCard(at now: Date) -> CardSchedule {
        guard let waiting = waitingCard, let next = nextCardAt else { return self }
        return showing(waiting, at: now, engaged: true)
            .closed(at: next.addingTimeInterval(-settings.interval))
    }

    /// A timed card is due but cannot show now (the tray is open under the icon):
    /// look again after the same short delay the quiet rules use.
    func retryingSoon(at now: Date) -> CardSchedule {
        noCard(.fullScreen, at: now)
    }
}
