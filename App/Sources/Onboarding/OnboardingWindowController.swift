import AppKit
import OSLog
import SwiftUI

/// The first-run window. Closing it with × counts as finishing: onboarding
/// never comes back, and the learner can change everything in Settings.
@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private let model: OnboardingModel
    private let window: NSWindow
    private let onFinish: () -> Void
    private var isFinished = false
    private var isClosing = false
    private let logger = Logger(subsystem: "com.niklod.LingvoBuddy", category: "onboarding")

    init(
        model: OnboardingModel,
        settings: SettingsModel,
        focus: any FocusAccessRequesting,
        launchAtLogin: any LaunchAtLoginControlling,
        errors: ErrorPresenter,
        onFinish: @escaping () -> Void
    ) {
        self.model = model
        self.onFinish = onFinish
        self.window = Self.makeWindow(root: OnboardingView(
            model: model,
            settings: settings,
            focus: focus,
            launchAtLogin: launchAtLogin,
            errors: errors
        ))
        super.init()
        window.delegate = self
        model.onFinish = { [weak self] in self?.finished() }
    }

    func show() {
        ForegroundWindows.show(window)
        logger.notice("onboarding shown, active: \(NSApp.isActive)")
    }

    func windowWillClose(_ notification: Notification) {
        isClosing = true
        ForegroundWindows.willClose(window)
        guard !isFinished else { return }
        logger.notice("onboarding closed before the last step")
        model.finish()
    }

    private func finished() {
        guard !isFinished else { return }
        isFinished = true
        logger.notice("onboarding finished")
        if !isClosing {
            window.close()
        }
        onFinish()
    }

    /// The default sizing makes the window follow the content height, which changes with the step.
    private static func makeWindow(root: OnboardingView) -> NSWindow {
        NSWindow.themed(
            root,
            title: String(localized: "Welcome to LingvoBuddy"),
            style: [.titled, .closable],
            hidesTitle: true
        )
    }
}
