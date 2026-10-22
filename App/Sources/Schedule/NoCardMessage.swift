import LingvoCore

enum NoCardMessage {
    static func text(for reason: NoCardReason) -> String {
        switch reason {
        case .noWordsAvailable:
            String(localized: "There are no words to practice right now.")
        case .paused, .quietHours, .focus, .fullScreen:
            // Only timed cards get these reasons, and the timer never shows a message.
            String(localized: "Cards are on hold right now.")
        }
    }
}
