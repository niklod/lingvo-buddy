import AppKit
import CoreGraphics

@MainActor
protocol FullScreenDetecting {
    func isOtherAppFullScreen() -> Bool
}

/// There is no public "is app X in a full-screen Space" API. Two cheap signals
/// together cover native full screen and borderless "fake" full screen (games,
/// Keynote): the system presentation options and a frontmost-app window that
/// covers a whole display. Window bounds need no Screen Recording permission;
/// only window titles do, and this never reads them.
@MainActor
struct FullScreenDetector: FullScreenDetecting {
    func isOtherAppFullScreen() -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return false }
        return NSApp.currentSystemPresentationOptions.contains(.fullScreen)
            || hasDisplaySizedWindow(pid: app.processIdentifier)
    }

    private func hasDisplaySizedWindow(pid: pid_t) -> Bool {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        let displaySizes = NSScreen.screens.map(\.frame.size)
        return windows.contains { window in
            guard (window[kCGWindowOwnerPID as String] as? pid_t) == pid,
                  (window[kCGWindowLayer as String] as? Int) == 0,
                  let bounds = window[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds) else { return false }
            return displaySizes.contains(rect.size)
        }
    }
}
