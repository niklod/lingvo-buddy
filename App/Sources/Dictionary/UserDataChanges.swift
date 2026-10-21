import Foundation

/// Tells open views that the learner's words changed outside them: a card was
/// answered or quick add added a word while the Dictionary window was open.
enum UserDataChanges {
    static let notification = Notification.Name("com.niklod.LingvoBuddy.userDataChanged")

    static func post() {
        NotificationCenter.default.post(name: notification, object: nil)
    }
}
