import Foundation

/// Tells open views and the card schedule that the learner's words changed
/// outside them: a card was answered, quick add added a word, a Dictionary row
/// action ran, a CSV import or the level check rewrote progress.
enum UserDataChanges {
    /// Which cards the change makes stale. A card in memory (shown, waiting
    /// behind the dot, or postponed) for a stale word would fail on answer or
    /// change progress the learner just set by hand.
    enum StaleCards: Equatable {
        /// An answer or a new word: every card is still valid.
        case none
        case words(Set<String>)
        /// A bulk change with no word list (import, level check).
        case all

        func contains(_ headword: String) -> Bool {
            switch self {
            case .none: false
            case .words(let headwords): headwords.contains(headword)
            case .all: true
            }
        }
    }

    static let notification = Notification.Name("com.niklod.LingvoBuddy.userDataChanged")
    private static let staleCardsKey = "staleCards"

    /// `sender` lets a view that already reloaded skip its own change.
    static func post(staleCards: StaleCards = .none, sender: AnyObject? = nil) {
        NotificationCenter.default.post(name: notification, object: sender, userInfo: [staleCardsKey: staleCards])
    }

    static func staleCards(in notification: Notification) -> StaleCards {
        notification.userInfo?[staleCardsKey] as? StaleCards ?? .none
    }
}
