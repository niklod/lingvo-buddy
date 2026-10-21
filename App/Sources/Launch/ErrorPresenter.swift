import AppKit
import OSLog

/// Shows problems to the learner in plain words and logs the details.
@MainActor
struct ErrorPresenter {
    private let logger = Logger(subsystem: "com.niklod.LingvoBuddy", category: "errors")

    func show(_ error: Error, title: String = String(localized: "Something went wrong")) {
        logger.error("\(String(describing: error), privacy: .public)")
        present(title: title, message: error.localizedDescription)
    }

    func inform(_ message: String) {
        present(title: "LingvoBuddy", message: message)
    }

    private func present(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        // A menu-bar app has no active window, so the alert would open behind other apps.
        NSApp.activate()
        alert.runModal()
    }
}
